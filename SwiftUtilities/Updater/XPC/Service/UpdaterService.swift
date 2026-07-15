/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Jean-David Gadina - www.xs-labs.com
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the Software), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED AS IS, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 ******************************************************************************/

import Foundation

/// The updater service's exported object: the ``UpdaterServiceProtocol`` the app
/// calls across the XPC connection.
///
/// It runs off the sandbox, inside the framework-bundled updater service, so it can
/// perform the privileged file operations the app cannot. For each request it
/// composes the M3/M5/M6 building blocks into the security-first
/// extract → validate → replace install (via ``UpdateInstallation``),
/// validating the extracted application against the identity carried in the request
/// through an ``ExpectedIdentityInspector`` (the service's own identity is not the
/// application's, so it cannot be derived here). Progress is streamed back through
/// the injected `reportProgress` sink — wired to the connection's client proxy by
/// the listener — and the terminal result is returned through the reply block.
///
/// Every dependency is injected, so the composition and its decode/report/reply
/// behavior are unit-testable with stubs, without a live connection or a signed
/// application. The listener supplies the production dependencies (the real archive
/// extractor, Security-backed inspector, and on-disk replacer).
///
/// The relaunch is armed as the **last step of a successful install**, not as a
/// separate later request: once the install replaces the application bundle — which
/// contains this service — the running app can no longer reach the service (its XPC
/// connection dies with "Couldn't communicate with a helper application"). So while
/// the connection is still healthy, the service spawns the detached relaunch helper
/// off the sandbox; the helper waits for the app to quit and reopens it only if the
/// user asked to relaunch (a sentinel file the app writes — see ``RelaunchWaiter``).
public final class UpdaterService: NSObject, UpdaterServiceProtocol
{
    /// Unpacks the archive and locates the application.
    private let extractor: ArchiveExtracting

    /// Verifies the extracted application's real code signature.
    private let inspector: CodeSignatureInspecting

    /// Replaces the application on disk.
    private let replacer: AppReplacing

    /// Streams each install phase back to the app.
    private let reportProgress: @Sendable ( InstallProgress ) -> Void

    /// Spawns the detached relaunch helper. Injected so the relaunch scheduling can
    /// be tested without starting a process.
    private let spawnRelaunch: @Sendable ( URL, [ String ] ) throws -> Void

    /// Resolves the executable to re-invoke in relaunch-wait mode. Injected so the
    /// relaunch scheduling can be tested without depending on `Bundle.main`.
    private let relaunchExecutable: @Sendable () -> URL?

    /// Creates the exported object from its injected dependencies.
    ///
    /// - Parameters:
    ///   - extractor:          Unpacks the archive and locates the application.
    ///   - inspector:          Performs the real code-signature verification.
    ///   - replacer:           Replaces the application on disk.
    ///   - reportProgress:     Streams each ``InstallProgress`` phase back to the app.
    ///   - spawnRelaunch:      Spawns the detached relaunch helper. Defaults to
    ///                         ``ProcessRelauncher/spawnDetached(_:_:)``.
    ///   - relaunchExecutable: Resolves the executable to re-invoke in relaunch-wait
    ///                         mode. Defaults to the service's own executable
    ///                         (`Bundle.main.executableURL`).
    public init(
        extractor:          ArchiveExtracting,
        inspector:          CodeSignatureInspecting,
        replacer:           AppReplacing,
        reportProgress:     @escaping @Sendable ( InstallProgress ) -> Void,
        spawnRelaunch:      @escaping @Sendable ( URL, [ String ] ) throws -> Void = ProcessRelauncher.spawnDetached,
        relaunchExecutable: @escaping @Sendable () -> URL?                         = { Bundle.main.executableURL }
    )
    {
        self.extractor          = extractor
        self.inspector          = inspector
        self.replacer           = replacer
        self.reportProgress     = reportProgress
        self.spawnRelaunch      = spawnRelaunch
        self.relaunchExecutable = relaunchExecutable

        super.init()
    }

    /// Installs a downloaded update on behalf of the app.
    ///
    /// Decodes the request, runs the install, and returns the encoded terminal
    /// result through `reply`. The work runs on a detached task so the XPC method
    /// returns immediately; `reply` is invoked exactly once when the install
    /// finishes, whether it succeeds or fails.
    ///
    /// - Parameters:
    ///   - request: An ``UpdateInstallRequest`` in its encoded `Data` form.
    ///   - reply:   Called once with an encoded ``UpdateInstallResult``.
    public func installUpdate( _ request: Data, withReply reply: @escaping @Sendable ( Data ) -> Void )
    {
        let extractor          = self.extractor
        let inspector          = self.inspector
        let replacer           = self.replacer
        let reportProgress     = self.reportProgress
        let spawnRelaunch      = self.spawnRelaunch
        let relaunchExecutable = self.relaunchExecutable

        Task
        {
            let result = await UpdaterService.run(
                request:            request,
                extractor:          extractor,
                inspector:          inspector,
                replacer:           replacer,
                reportProgress:     reportProgress,
                spawnRelaunch:      spawnRelaunch,
                relaunchExecutable: relaunchExecutable
            )

            reply( UpdaterService.encode( result ) )
        }
    }

    /// Runs the install for an encoded request and returns the terminal result.
    ///
    /// This is the testable core, free of the XPC and task plumbing: it decodes the
    /// request, builds the ``UpdateInstallation`` (validating against the request's
    /// identity and verifying the download's deployment target against the host),
    /// runs it, and — on success — arms the relaunch by spawning the detached helper
    /// (see ``armRelaunch(processIdentifier:application:sentinel:executableURL:spawn:)``)
    /// before returning. It never throws — a failure is reported as
    /// ``UpdateInstallResult/failure(reason:)`` — so the caller always has a result
    /// to reply with.
    ///
    /// The relaunch helper is spawned **here**, as the last step of a successful
    /// install, while the service and its XPC connection are still healthy: after the
    /// install replaces the app bundle, the app can no longer reach the service to
    /// ask for one.
    ///
    /// - Parameters:
    ///   - request:            The encoded ``UpdateInstallRequest``.
    ///   - extractor:          Unpacks the archive and locates the application.
    ///   - inspector:          Performs the real code-signature verification.
    ///   - replacer:           Replaces the application on disk.
    ///   - reportProgress:     Streams each phase back to the app.
    ///   - spawnRelaunch:      Spawns the detached relaunch helper.
    ///   - relaunchExecutable: Resolves the executable to re-invoke in relaunch-wait
    ///                         mode.
    ///
    /// - Returns: The terminal ``UpdateInstallResult``.
    static func run(
        request:            Data,
        extractor:          ArchiveExtracting,
        inspector:          CodeSignatureInspecting,
        replacer:           AppReplacing,
        reportProgress:     @escaping @Sendable ( InstallProgress ) -> Void,
        spawnRelaunch:      @Sendable ( URL, [ String ] ) throws -> Void = { _, _ in },
        relaunchExecutable: @Sendable () -> URL?                          = { nil }
    ) async -> UpdateInstallResult
    {
        do
        {
            let decoded      = try UpdateInstallRequest.decoded( from: request )
            let validator    = CodeSignatureValidator( inspector: ExpectedIdentityInspector( expected: decoded.identity, base: inspector ) )
            let verifier     = DeploymentTargetVerifier()
            let installation = UpdateInstallation( extractor: extractor, validator: validator, verifier: verifier, replacer: replacer )

            let installed = try await installation.installReturningLocation( archive: decoded.archiveURL, format: decoded.format, replacing: decoded.targetURL, progress: reportProgress )

            UpdaterService.armRelaunch(
                processIdentifier: decoded.processIdentifier,
                application:       installed,
                sentinel:          decoded.relaunchSentinelURL,
                executableURL:     relaunchExecutable(),
                spawn:             spawnRelaunch
            )

            return .success
        }
        catch
        {
            return .failure( from: error )
        }
    }

    /// Arms the relaunch by spawning the detached helper, off the sandbox.
    ///
    /// Re-invokes the given executable in relaunch-wait mode, passing the application
    /// to reopen, the process to wait on, and the sentinel the helper checks before
    /// reopening. This is **best-effort**: a relaunch that cannot be armed (no
    /// resolvable executable, or a spawn failure) does not fail the install, which
    /// has already succeeded — the update simply takes effect on the next manual
    /// launch instead.
    ///
    /// - Parameters:
    ///   - processIdentifier: The application process the helper waits on.
    ///   - application:       The application bundle to reopen.
    ///   - sentinel:          The sentinel file the helper checks before reopening.
    ///   - executableURL:     The executable to re-invoke in relaunch-wait mode, or
    ///                        `nil` if it cannot be resolved.
    ///   - spawn:             Spawns the detached helper.
    static func armRelaunch( processIdentifier: Int32, application: URL, sentinel: URL, executableURL: URL?, spawn: @Sendable ( URL, [ String ] ) throws -> Void )
    {
        guard let executableURL
        else
        {
            return
        }

        let invocation = ProcessRelauncher.Invocation( processIdentifier: processIdentifier, application: application, sentinel: sentinel )

        try? spawn( executableURL, ProcessRelauncher.arguments( for: invocation ) )
    }

    /// Encodes a result for the reply block, never failing.
    ///
    /// A result of these value types always encodes; the fallbacks exist only so the
    /// signature can promise a `Data` to reply with even in the impossible event of
    /// an encoding failure.
    ///
    /// - Parameter result: The result to encode.
    ///
    /// - Returns: The encoded result.
    private static func encode( _ result: UpdateInstallResult ) -> Data
    {
        if let data = try? result.encoded()
        {
            return data
        }

        return ( try? UpdateInstallResult.failure( reason: "The update result could not be encoded." ).encoded() ) ?? Data()
    }
}
