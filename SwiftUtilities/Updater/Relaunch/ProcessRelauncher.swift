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

/// Stages and spawns the relaunch helper that outlives the update.
///
/// The relaunch — wait for the application to quit, then reopen it — must run from a
/// process that survives both the application and the updater service. Because an
/// install replaces the application bundle (which contains the service), the helper
/// is **staged** as a whole-bundle copy outside the app before the install
/// (``stageRelaunchBundle(forApplicationAt:from:)``), and the app **spawns** that
/// staged copy on the user's request (``spawnStagedRelaunch(forApplicationAt:waitingFor:spawn:)``).
/// The spawned copy re-invokes the service executable in relaunch mode (see
/// ``arguments(for:)``): the service's `main` recognizes those arguments and runs a
/// ``RelaunchWaiter`` instead of the XPC listener, detached via `setsid` so it
/// outlives its parent.
///
/// This is a namespace of static helpers — there is no per-relaunch instance state —
/// and the spawn is injectable, so the staging and argument logic are unit-testable
/// without starting a process.
public enum ProcessRelauncher
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

    /// A file URL to the running service bundle, used as the staging source.
    public static var runningBundleURL: URL
    {
        Bundle.main.bundleURL
    }

    /// The directory under which relaunch bundles are staged.
    ///
    /// A single root under the user's temporary directory, holding one keyed
    /// subdirectory per target application.
    private static var stagingRootURL: URL
    {
        FileManager.default.temporaryDirectory.appendingPathComponent( "com.xs-labs.SwiftUtilities.Updater", isDirectory: true )
    }

    /// The stable location the relaunch **bundle** is staged to for a target.
    ///
    /// The whole service bundle is staged — not just its executable — because an XPC
    /// service's code signature covers the bundle (its `Info.plist`, resources, and
    /// `_CodeSignature`); a lone executable copied out fails validation and the
    /// hardened runtime kills it on launch. The path is derived deterministically
    /// from the application's location, so the install step (which stages the copy)
    /// and the later relaunch step (which spawns from it) — potentially different
    /// service processes — agree on it without sharing any state. Keying by the
    /// target keeps concurrent updates of different applications from colliding.
    ///
    /// - Parameter application: The application bundle that will be reopened.
    ///
    /// - Returns: The location the relaunch bundle is staged to.
    public static func stagedBundleURL( forApplicationAt application: URL ) -> URL
    {
        let key = ProcessRelauncher.stableKey( for: application.standardizedFileURL.path )

        return ProcessRelauncher.stagingRootURL.appendingPathComponent( key, isDirectory: true ).appendingPathComponent( "relaunch.xpc", isDirectory: true )
    }

    /// The executable inside the staged relaunch bundle, if it is present.
    ///
    /// Resolves the staged bundle's executable through its `Info.plist`
    /// (`CFBundleExecutable`), so it does not depend on the executable's name.
    ///
    /// - Parameter application: The application whose staged bundle to inspect.
    ///
    /// - Returns: The staged executable's URL, or `nil` if nothing valid is staged.
    public static func stagedRelaunchExecutableURL( forApplicationAt application: URL ) -> URL?
    {
        let bundleURL = ProcessRelauncher.stagedBundleURL( forApplicationAt: application )

        guard let executableURL = Bundle( url: bundleURL )?.executableURL,
              FileManager.default.isExecutableFile( atPath: executableURL.path )
        else
        {
            return nil
        }

        return executableURL
    }

    /// Stages a copy of the whole service bundle outside the application bundle.
    ///
    /// Called during install, **before** the application is replaced, while the
    /// service bundle is still on disk. It copies that bundle to the stable staged
    /// location for the target (see ``stagedBundleURL(forApplicationAt:)``),
    /// replacing any previous copy, so the relaunch can later run from a location the
    /// update cannot remove — the way Sparkle runs its updater from a cache copy. The
    /// whole bundle is copied so its code signature stays valid.
    ///
    /// - Parameters:
    ///   - application: The application bundle that will be reopened.
    ///   - bundleURL:   The service bundle to stage. Defaults to the running bundle.
    ///
    /// - Returns: The staged bundle's location.
    ///
    /// - Throws: An error if the copy cannot be made.
    @discardableResult
    public static func stageRelaunchBundle( forApplicationAt application: URL, from bundleURL: URL = ProcessRelauncher.runningBundleURL ) throws -> URL
    {
        let destination = ProcessRelauncher.stagedBundleURL( forApplicationAt: application )
        let directory   = destination.deletingLastPathComponent()
        let manager     = FileManager.default

        try? manager.removeItem( at: directory )
        try manager.createDirectory( at: directory, withIntermediateDirectories: true )
        try manager.copyItem( at: bundleURL, to: destination )

        return destination
    }

    /// Removes the staged relaunch bundle for a target application, if present.
    ///
    /// Called after the relaunch has reopened the application, to keep the staging
    /// area from accumulating copies. Removing the running relaunch binary is safe:
    /// the process keeps executing from the open file after it is unlinked.
    ///
    /// - Parameter application: The application whose staged bundle to remove.
    public static func removeStagedRelaunchBundle( forApplicationAt application: URL )
    {
        let directory = ProcessRelauncher.stagedBundleURL( forApplicationAt: application ).deletingLastPathComponent()

        try? FileManager.default.removeItem( at: directory )
    }

    /// Spawns the previously staged relaunch helper, detached, for a target.
    ///
    /// This is the **client-side** relaunch: the application itself spawns the staged
    /// helper (see ``stageRelaunchBundle(forApplicationAt:from:)``) and then
    /// terminates, rather than asking the updater service to do it. The service
    /// cannot be used here — having just replaced its own containing application
    /// bundle on disk, the hardened runtime kills it as soon as it executes further
    /// code. The staged helper runs from a copy outside the bundle, so it is
    /// unaffected.
    ///
    /// - Parameters:
    ///   - application:       The application bundle to reopen once it exits.
    ///   - processIdentifier: The application's process identifier, to wait on.
    ///   - spawn:             Spawns the detached process. Defaults to
    ///                        ``spawnDetached(_:_:)``.
    ///
    /// - Throws: ``RelaunchError/relaunchHelperUnavailable`` if no staged helper is
    ///   present, or the underlying error if it cannot be spawned.
    public static func spawnStagedRelaunch(
        forApplicationAt application: URL,
        waitingFor processIdentifier: Int32,
        spawn:                        @escaping @Sendable ( URL, [ String ] ) throws -> Void = ProcessRelauncher.spawnDetached
    ) throws
    {
        guard let executable = ProcessRelauncher.stagedRelaunchExecutableURL( forApplicationAt: application )
        else
        {
            throw RelaunchError.relaunchHelperUnavailable
        }

        let invocation = Invocation( processIdentifier: processIdentifier, application: application )

        try spawn( executable, ProcessRelauncher.arguments( for: invocation ) )
    }

    /// A stable, process-independent key for a string (FNV-1a, 64-bit).
    ///
    /// `String.hashValue` is randomly seeded per process, so it cannot be used to
    /// build a path two different processes must agree on. This is a plain FNV-1a
    /// hash, whose value depends only on the input.
    ///
    /// - Parameter string: The string to hash.
    ///
    /// - Returns: The hash as a hexadecimal string.
    private static func stableKey( for string: String ) -> String
    {
        let hash = string.utf8.reduce( UInt64( 0xcbf2_9ce4_8422_2325 ) )
        {
            ( $0 ^ UInt64( $1 ) ) &* 0x0000_0100_0000_01b3
        }

        return String( hash, radix: 16 )
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
