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

/// The app-side installer that hands an update off to the bundled updater service.
///
/// This is the single in-app install path. It runs in the application process, so
/// it derives the **application's** own signing identity (the root of trust) from
/// the running code and puts it in the request; the service validates the download
/// against it. It then forwards the request over the injected
/// ``UpdaterServiceConnecting`` transport, relays the service's progress to the
/// caller, and maps the terminal result to a return or a thrown error.
///
/// It conforms to ``UpdateInstaller`` so the UI drives it exactly like any other
/// installer. The `workingDirectory` argument is ignored: the privileged file work
/// runs in the service, which stages the update on the target's own volume. The
/// identity read and the transport are injected, so the request-building and
/// result-mapping are unit-testable without a live connection or a signed app.
public struct XPCUpdateInstaller: UpdateInstaller
{
    /// Reads the running application's signing identity.
    private let inspector: CodeSignatureInspecting

    /// The transport to the bundled service.
    private let connector: UpdaterServiceConnecting

    /// The running application's process identifier, sent so the service can wait
    /// for the app to exit before relaunching.
    private let processIdentifier: Int32

    /// The sentinel the app writes to request a relaunch, sent so the service can arm
    /// the relaunch helper during the install (the app cannot reach the service after
    /// the install replaces its bundle).
    private let relaunchSentinel: URL

    /// Creates an installer from its injected dependencies.
    ///
    /// - Parameters:
    ///   - inspector:         Reads the running application's signing identity.
    ///   - connector:         The transport to the bundled service.
    ///   - processIdentifier: The running application's process identifier.
    ///   - relaunchSentinel:  The sentinel the app writes to request a relaunch.
    init( inspector: CodeSignatureInspecting, connector: UpdaterServiceConnecting, processIdentifier: Int32, relaunchSentinel: URL )
    {
        self.inspector         = inspector
        self.connector         = connector
        self.processIdentifier = processIdentifier
        self.relaunchSentinel  = relaunchSentinel
    }

    /// Hands the update off to the bundled service and awaits the outcome.
    ///
    /// - Parameters:
    ///   - archive:          A file URL to the downloaded archive.
    ///   - format:           The archive's format.
    ///   - target:           A file URL to the application bundle to replace.
    ///   - workingDirectory: Ignored; the service stages the update itself.
    ///   - progress:         Invoked as each ``InstallProgress`` phase is reported.
    ///
    /// - Throws: ``UpdateInstallError/installationFailed(reason:)`` if the service
    ///   reports a failure, or the underlying error if the running identity cannot
    ///   be read or the connection is dropped.
    public func install( archive: URL, format: UpdateArchiveFormat, replacing target: URL, into workingDirectory: URL, progress: @escaping @Sendable ( InstallProgress ) -> Void ) async throws
    {
        let identity = try self.inspector.runningApplicationIdentity()
        let request  = UpdateInstallRequest( archive: archive, target: target, identity: identity, format: format, processIdentifier: self.processIdentifier, relaunchSentinel: self.relaunchSentinel )

        let resultData = try await self.connector.installUpdate( try request.encoded() )
        {
            data in

            guard let phase = try? InstallProgress.decoded( from: data )
            else
            {
                return
            }

            progress( phase )
        }

        switch try UpdateInstallResult.decoded( from: resultData )
        {
            case .success:

                return

            case .failure( let reason ):

                throw UpdateInstallError.installationFailed( reason: reason )
        }
    }
}

#if canImport( Security )

    public extension XPCUpdateInstaller
    {
        /// Creates a production installer backed by the Security framework and a live
        /// connection to the bundled service.
        ///
        /// Reads the running application's identity with
        /// ``SecurityCodeSignatureInspector`` and connects through
        /// ``XPCUpdaterServiceConnection``.
        ///
        /// - Parameters:
        ///   - serviceName:      The bundle identifier of the updater service.
        ///                       Defaults to ``UpdaterServiceLocator/serviceName``.
        ///   - relaunchSentinel: The sentinel the app writes to request a relaunch.
        init( serviceName: String = UpdaterServiceLocator.serviceName, relaunchSentinel: URL )
        {
            self.init(
                inspector:         SecurityCodeSignatureInspector(),
                connector:         XPCUpdaterServiceConnection( serviceName: serviceName ),
                processIdentifier: ProcessInfo.processInfo.processIdentifier,
                relaunchSentinel:  relaunchSentinel
            )
        }
    }

#endif
