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

/// Encodes relaunch invocations and spawns the detached relaunch helper.
///
/// The relaunch — wait for the application to quit, then reopen it — must run from a
/// process that survives both the application and the updater service. It is spawned
/// **off the sandbox by the bundled service** as the last step of a successful
/// install (see ``UpdaterService``), which re-invokes its own executable with the
/// arguments built here: the spawned copy's `main` recognizes them (see
/// ``invocation(from:)``) and runs a ``RelaunchWaiter`` instead of the XPC listener,
/// detached via `setsid` so it outlives its parent.
///
/// This is a namespace of static helpers — there is no per-relaunch instance state —
/// and the spawn is injectable, so the argument logic is unit-testable without
/// starting a process.
public enum ProcessRelauncher
{
    /// A relaunch request encoded into, or decoded from, process arguments.
    public struct Invocation: Equatable, Sendable
    {
        /// The application process to wait for before reopening.
        public let processIdentifier: Int32

        /// A file URL to the application bundle to reopen.
        public let application: URL

        /// A file URL to the sentinel the helper checks before reopening: it reopens
        /// the application only if this file is present when the application exits.
        public let sentinel: URL

        /// Creates an invocation.
        ///
        /// - Parameters:
        ///   - processIdentifier: The application process to wait for.
        ///   - application:       A file URL to the application bundle to reopen.
        ///   - sentinel:          A file URL to the relaunch-request sentinel.
        public init( processIdentifier: Int32, application: URL, sentinel: URL )
        {
            self.processIdentifier = processIdentifier
            self.application       = application
            self.sentinel          = sentinel
        }
    }

    /// The flag marking a relaunch-mode invocation of the service executable.
    public static let waitArgument = "--updater-relaunch-wait"

    /// Builds the process arguments (excluding `argv[0]`) for a relaunch invocation.
    ///
    /// - Parameter invocation: The relaunch request to encode.
    ///
    /// - Returns: The argument array to pass to the spawned executable.
    public static func arguments( for invocation: Invocation ) -> [ String ]
    {
        [ ProcessRelauncher.waitArgument, String( invocation.processIdentifier ), invocation.application.path, invocation.sentinel.path ]
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
        guard commandLineArguments.count >= 5,
              commandLineArguments[ 1 ] == ProcessRelauncher.waitArgument,
              let processIdentifier = Int32( commandLineArguments[ 2 ] )
        else
        {
            return nil
        }

        return Invocation( processIdentifier: processIdentifier, application: URL( fileURLWithPath: commandLineArguments[ 3 ] ), sentinel: URL( fileURLWithPath: commandLineArguments[ 4 ] ) )
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
