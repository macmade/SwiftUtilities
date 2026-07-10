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

/// Relaunches the application from a detached process that outlives the update.
///
/// This is the concrete relaunch step the updater service runs. The service (and
/// the application) are both about to go away, so the wait-and-reopen cannot happen
/// inside them. Instead ``relaunch(_:)`` spawns a **detached** copy of the service's
/// own executable, re-invoked in relaunch mode (see ``arguments(for:)``); the
/// service's `main` recognizes those arguments and runs a ``RelaunchWaiter`` instead
/// of the XPC listener. When the service exits, that child is reparented to `launchd`
/// and keeps running until the application has quit, then reopens it — no shell and
/// no consumer-built helper, just the service binary in a second mode.
///
/// The spawn is injected, so what gets launched is unit-testable without actually
/// starting a process. The `processIdentifier` (the application's PID) is captured
/// at construction, matching the ``UpdateInstallRequest`` the service is handling.
///
/// > Note: The exact surviving-process guarantee (reparenting, and whether a new
/// > session via `setsid` is required so the child is not torn down with the
/// > service's job) can only be confirmed at runtime with a signed, embedded
/// > service; it is documented here and verified there.
public struct ProcessRelauncher: ApplicationRelaunching
{
    /// A relaunch request encoded into, or decoded from, process arguments.
    public struct Invocation: Equatable, Sendable
    {
        /// The application process to wait for before reopening.
        public let processIdentifier: Int32

        /// A file URL to the application bundle to reopen.
        public let application: URL

        /// Creates an invocation.
        ///
        /// - Parameters:
        ///   - processIdentifier: The application process to wait for.
        ///   - application:       A file URL to the application bundle to reopen.
        public init( processIdentifier: Int32, application: URL )
        {
            self.processIdentifier = processIdentifier
            self.application       = application
        }
    }

    /// The flag marking a relaunch-mode invocation of the service executable.
    public static let waitArgument = "--updater-relaunch-wait"

    /// The application process to wait for before reopening.
    private let processIdentifier: Int32

    /// The executable to re-invoke in relaunch mode (the service's own binary).
    private let executableURL: URL

    /// Spawns the detached relaunch process.
    private let spawn: @Sendable ( URL, [ String ] ) throws -> Void

    /// Creates a relauncher.
    ///
    /// - Parameters:
    ///   - processIdentifier: The application's process identifier, from the request.
    ///   - executableURL:     The executable to re-invoke in relaunch mode. Defaults
    ///                        to the running executable (the service binary).
    ///   - spawn:             Spawns the detached process. Defaults to
    ///                        ``ProcessRelauncher/spawnDetached(_:_:)``.
    public init(
        processIdentifier: Int32,
        executableURL:     URL                                          = ProcessRelauncher.runningExecutableURL,
        spawn:             @escaping @Sendable ( URL, [ String ] ) throws -> Void = ProcessRelauncher.spawnDetached
    )
    {
        self.processIdentifier = processIdentifier
        self.executableURL     = executableURL
        self.spawn             = spawn
    }

    /// Schedules the relaunch by spawning the detached waiter process.
    ///
    /// Returns as soon as the process is launched; the actual wait-and-reopen
    /// happens in the detached child after the application quits.
    ///
    /// - Parameter application: A file URL to the installed application bundle.
    ///
    /// - Throws: An error if the detached process cannot be spawned.
    public func relaunch( _ application: URL ) throws
    {
        let invocation = Invocation( processIdentifier: self.processIdentifier, application: application )

        try self.spawn( self.executableURL, ProcessRelauncher.arguments( for: invocation ) )
    }

    /// Builds the process arguments (excluding `argv[0]`) for a relaunch invocation.
    ///
    /// - Parameter invocation: The relaunch request to encode.
    ///
    /// - Returns: The argument array to pass to the spawned executable.
    public static func arguments( for invocation: Invocation ) -> [ String ]
    {
        [ ProcessRelauncher.waitArgument, String( invocation.processIdentifier ), invocation.application.path ]
    }

    /// Parses a relaunch invocation from a process's full command-line arguments.
    ///
    /// Expects `CommandLine.arguments`, whose first element is the executable path;
    /// returns `nil` when the arguments are not a relaunch invocation.
    ///
    /// - Parameter commandLineArguments: The full argument list, including `argv[0]`.
    ///
    /// - Returns: The decoded ``Invocation``, or `nil` if the arguments are not a
    ///   relaunch invocation.
    public static func invocation( from commandLineArguments: [ String ] ) -> Invocation?
    {
        guard commandLineArguments.count >= 4,
              commandLineArguments[ 1 ] == ProcessRelauncher.waitArgument,
              let processIdentifier = Int32( commandLineArguments[ 2 ] )
        else
        {
            return nil
        }

        return Invocation( processIdentifier: processIdentifier, application: URL( fileURLWithPath: commandLineArguments[ 3 ] ) )
    }

    /// A file URL to the running executable, used as the relaunch binary.
    public static var runningExecutableURL: URL
    {
        if let url = Bundle.main.executableURL
        {
            return url
        }

        return URL( fileURLWithPath: CommandLine.arguments.first ?? "" )
    }

    /// Spawns a detached copy of the executable with the given arguments.
    ///
    /// The child is started with `POSIX_SPAWN_SETSID`, so it becomes a session
    /// leader in a **new session**, detached from the updater service's `launchd`
    /// job. This is what lets it outlive both the application and the service: a
    /// plain child would remain in the service's job and could be terminated with it
    /// when the service exits or idle-times-out, and the relaunch would be lost.
    ///
    /// - Parameters:
    ///   - executableURL: The executable to run.
    ///   - arguments:     The arguments (excluding `argv[0]`).
    ///
    /// - Throws: ``RelaunchError/relaunchProcessFailed(code:)`` if the process
    ///   cannot be spawned.
    public static func spawnDetached( _ executableURL: URL, _ arguments: [ String ] ) throws
    {
        let path      = executableURL.path
        let arguments = [ path ] + arguments

        var attributes: posix_spawnattr_t?

        posix_spawnattr_init( &attributes )

        defer
        {
            posix_spawnattr_destroy( &attributes )
        }

        posix_spawnattr_setflags( &attributes, Int16( POSIX_SPAWN_SETSID ) )

        let argv = arguments.map { strdup( $0 ) } + [ nil ]

        defer
        {
            argv.forEach { free( $0 ) }
        }

        var pid    = pid_t()
        let status = posix_spawn( &pid, path, nil, &attributes, argv, environ )

        guard status == 0
        else
        {
            throw RelaunchError.relaunchProcessFailed( code: status )
        }
    }
}
