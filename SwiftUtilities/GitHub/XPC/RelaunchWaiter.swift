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

/// Waits for the updated application to quit, then reopens it.
///
/// This runs inside the detached relaunch process (spawned by
/// ``ProcessRelauncher``), which outlives both the application and the updater
/// service. It polls the application's process until it exits — macOS will not
/// launch a second instance of an app that is still running, so the old copy must
/// be gone first — then launches the freshly installed bundle.
///
/// The process-liveness check and the launch are injected, so the wait/open logic
/// is unit-testable without a real process or launching anything. Production uses
/// ``isProcessRunning(_:)`` (a signal-0 probe) and ``open(_:)`` (`/usr/bin/open`,
/// argv only, no shell).
public struct RelaunchWaiter: Sendable
{
    /// Returns whether the process with the given identifier is still running.
    private let isRunning: @Sendable ( Int32 ) -> Bool

    /// Launches the application bundle at the given URL.
    private let open: @Sendable ( URL ) throws -> Void

    /// How long to wait between liveness checks.
    private let pollInterval: TimeInterval

    /// The longest to wait for the application to exit before giving up.
    private let timeout: TimeInterval

    /// Creates a waiter.
    ///
    /// - Parameters:
    ///   - pollInterval: How long to wait between liveness checks. Defaults to
    ///                   0.2 seconds.
    ///   - timeout:      The longest to wait for the application to exit. Defaults
    ///                   to 10 minutes; past it the relaunch is abandoned rather
    ///                   than reopening while the old copy may still run.
    ///   - isRunning:    Returns whether a process is still running. Defaults to a
    ///                   signal-0 probe.
    ///   - open:         Launches the application bundle. Defaults to
    ///                   ``RelaunchWaiter/launch(_:)``.
    public init(
        pollInterval: TimeInterval                        = 0.2,
        timeout:      TimeInterval                        = 600,
        isRunning:    @escaping @Sendable ( Int32 ) -> Bool       = RelaunchWaiter.isProcessRunning,
        open:         @escaping @Sendable ( URL ) throws -> Void  = RelaunchWaiter.launch
    )
    {
        self.pollInterval = pollInterval
        self.timeout      = timeout
        self.isRunning    = isRunning
        self.open         = open
    }

    /// Waits for the given process to exit, then reopens the application.
    ///
    /// - Parameters:
    ///   - processIdentifier: The application process to wait for.
    ///   - application:       A file URL to the application bundle to reopen.
    ///
    /// - Throws: ``RelaunchError/timedOutWaitingForExit`` if the process does not
    ///   exit within the timeout, or an error from the launch if reopening fails.
    public func waitForExitThenOpen( processIdentifier: Int32, application: URL ) throws
    {
        let deadline = Date().addingTimeInterval( self.timeout )

        while self.isRunning( processIdentifier )
        {
            if Date() >= deadline
            {
                throw RelaunchError.timedOutWaitingForExit
            }

            Thread.sleep( forTimeInterval: self.pollInterval )
        }

        try self.open( application )
    }

    /// Reports whether a process is still running, using a signal-0 probe.
    ///
    /// `kill(pid, 0)` performs the permission and existence checks without sending a
    /// signal: success or an `EPERM` failure means the process exists, while `ESRCH`
    /// means it has exited.
    ///
    /// - Parameter processIdentifier: The process to probe.
    ///
    /// - Returns: `true` if the process still exists.
    public static func isProcessRunning( _ processIdentifier: Int32 ) -> Bool
    {
        if kill( processIdentifier, 0 ) == 0
        {
            return true
        }

        return errno == EPERM
    }

    /// Launches an application bundle via `/usr/bin/open`.
    ///
    /// Uses an argument array (no shell), so the path is never interpreted.
    ///
    /// - Parameter application: A file URL to the application bundle to launch.
    ///
    /// - Throws: An error if the launch tool cannot be run.
    public static func launch( _ application: URL ) throws
    {
        let process = Process()

        process.executableURL = URL( fileURLWithPath: "/usr/bin/open" )
        process.arguments     = [ application.path ]

        try process.run()
        process.waitUntilExit()
    }
}
