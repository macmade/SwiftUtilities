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
/// The service performs only the install. The relaunch is driven by the app itself
/// (it stages and spawns the helper): a service that has just replaced its own
/// containing bundle is killed by the hardened runtime as soon as it runs further
/// code, so it cannot be relied on afterward.
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

    /// Creates the exported object from its injected dependencies.
    ///
    /// - Parameters:
    ///   - extractor:      Unpacks the archive and locates the application.
    ///   - inspector:      Performs the real code-signature verification.
    ///   - replacer:       Replaces the application on disk.
    ///   - reportProgress: Streams each ``InstallProgress`` phase back to the app.
    public init(
        extractor:      ArchiveExtracting,
        inspector:      CodeSignatureInspecting,
        replacer:       AppReplacing,
        reportProgress: @escaping @Sendable ( InstallProgress ) -> Void
    )
    {
        self.extractor      = extractor
        self.inspector      = inspector
        self.replacer       = replacer
        self.reportProgress = reportProgress

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
        let extractor      = self.extractor
        let inspector      = self.inspector
        let replacer       = self.replacer
        let reportProgress = self.reportProgress

        Task
        {
            let result = await UpdaterService.run(
                request:        request,
                extractor:      extractor,
                inspector:      inspector,
                replacer:       replacer,
                reportProgress: reportProgress
            )

            reply( UpdaterService.encode( result ) )
        }
    }

    /// Runs the install for an encoded request and returns the terminal result.
    ///
    /// This is the testable core, free of the XPC and task plumbing: it decodes the
    /// request, builds the ``UpdateInstallation`` (validating against the request's
    /// identity and verifying the download's deployment target against the host),
    /// runs it, and maps success or any thrown error to an
    /// ``UpdateInstallResult``. It never throws — a failure is reported as
    /// ``UpdateInstallResult/failure(reason:)`` — so the caller always has a result
    /// to reply with.
    ///
    /// - Parameters:
    ///   - request:        The encoded ``UpdateInstallRequest``.
    ///   - extractor:      Unpacks the archive and locates the application.
    ///   - inspector:      Performs the real code-signature verification.
    ///   - replacer:       Replaces the application on disk.
    ///   - reportProgress: Streams each phase back to the app.
    ///
    /// - Returns: The terminal ``UpdateInstallResult``.
    static func run(
        request:        Data,
        extractor:      ArchiveExtracting,
        inspector:      CodeSignatureInspecting,
        replacer:       AppReplacing,
        reportProgress: @escaping @Sendable ( InstallProgress ) -> Void
    ) async -> UpdateInstallResult
    {
        do
        {
            let decoded      = try UpdateInstallRequest.decoded( from: request )
            let validator    = CodeSignatureValidator( inspector: ExpectedIdentityInspector( expected: decoded.identity, base: inspector ) )
            let verifier     = DeploymentTargetVerifier()
            let installation = UpdateInstallation( extractor: extractor, validator: validator, verifier: verifier, replacer: replacer )

            try await installation.install( archive: decoded.archiveURL, format: decoded.format, replacing: decoded.targetURL, progress: reportProgress )

            return .success
        }
        catch
        {
            return .failure( from: error )
        }
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
