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

/// The live `NSXPCConnection` transport to the bundled updater service.
///
/// This is the production ``UpdaterServiceConnecting``. For each request it opens a
/// connection to the framework-bundled service, wires the bidirectional interfaces
/// (the service's ``UpdaterServiceProtocol`` and the app's ``UpdaterClientProtocol``
/// for progress), forwards the encoded request, and bridges the reply — or a
/// connection failure — back to `async`. The connection is invalidated once the
/// call finishes.
///
/// It performs live IPC, so it is exercised by runtime verification rather than unit
/// tests; the request-building and result-mapping logic that *can* be tested lives
/// in ``XPCUpdateInstaller`` behind the ``UpdaterServiceConnecting`` seam.
public struct XPCUpdaterServiceConnection: UpdaterServiceConnecting
{
    /// The bundle identifier of the service to connect to.
    private let serviceName: String

    /// Creates a connection factory for the given service.
    ///
    /// - Parameter serviceName: The updater service's bundle identifier. Defaults to
    ///   ``UpdaterServiceLocator/serviceName``.
    public init( serviceName: String = UpdaterServiceLocator.serviceName )
    {
        self.serviceName = serviceName
    }

    /// Opens a connection, sends the request, and awaits the encoded result.
    ///
    /// The call completes when the service replies (the bundled service always
    /// replies, on success or failure) or when the connection is refused or dropped
    /// (surfaced through the proxy's error handler). It has **no timeout and is not
    /// cancellable**: a connected service that never replied nor dropped would leave
    /// the caller awaiting; the bundled service is trusted not to do so. Cancelling
    /// the surrounding task does not tear the connection down.
    ///
    /// - Parameters:
    ///   - request:  The encoded ``UpdateInstallRequest``.
    ///   - progress: Invoked with each encoded ``InstallProgress`` streamed back.
    ///
    /// - Returns: The encoded ``UpdateInstallResult``.
    ///
    /// - Throws: The underlying error if the connection is refused or dropped before
    ///   a result is delivered.
    public func installUpdate( _ request: Data, progress: @escaping @Sendable ( Data ) -> Void ) async throws -> Data
    {
        let connection = NSXPCConnection( serviceName: self.serviceName )

        connection.remoteObjectInterface = NSXPCInterface( with: UpdaterServiceProtocol.self )
        connection.exportedInterface     = NSXPCInterface( with: UpdaterClientProtocol.self )
        connection.exportedObject        = XPCUpdaterClient( handler: progress )

        connection.resume()

        defer
        {
            connection.invalidate()
        }

        return try await withCheckedThrowingContinuation
        {
            continuation in

            let resumer = SingleResumer( continuation )
            let proxy   = connection.remoteObjectProxyWithErrorHandler
            {
                error in

                resumer.resume( throwing: error )
            }

            guard let service = proxy as? UpdaterServiceProtocol
            else
            {
                resumer.resume( throwing: UpdateInstallError.serviceUnavailable )

                return
            }

            service.installUpdate( request )
            {
                result in

                resumer.resume( returning: result )
            }
        }
    }

    /// Resumes a checked continuation at most once, from any thread.
    ///
    /// The connection can complete either through the reply block or the proxy's
    /// error handler, and only one of them must resume the continuation — resuming a
    /// `CheckedContinuation` twice traps. This guards the hand-off under a lock.
    private final class SingleResumer< T: Sendable >: @unchecked Sendable
    {
        /// The lock guarding ``continuation``.
        private let lock = NSLock()

        /// The continuation to resume, cleared once resumed.
        private var continuation: CheckedContinuation< T, any Error >?

        /// Creates a resumer for the given continuation.
        ///
        /// - Parameter continuation: The continuation to resume exactly once.
        init( _ continuation: CheckedContinuation< T, any Error > )
        {
            self.continuation = continuation
        }

        /// Resumes the continuation with a value, if it has not resumed yet.
        ///
        /// - Parameter value: The value to return.
        func resume( returning value: T )
        {
            self.take()?.resume( returning: value )
        }

        /// Resumes the continuation with an error, if it has not resumed yet.
        ///
        /// - Parameter error: The error to throw.
        func resume( throwing error: any Error )
        {
            self.take()?.resume( throwing: error )
        }

        /// Atomically takes and clears the pending continuation.
        ///
        /// - Returns: The continuation the first time, `nil` on every later call.
        private func take() -> CheckedContinuation< T, any Error >?
        {
            self.lock.lock()

            defer
            {
                self.lock.unlock()
            }

            let continuation = self.continuation

            self.continuation = nil

            return continuation
        }
    }
}
