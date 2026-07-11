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

/// Unpacks a downloaded `.zip` or `.dmg` update archive and locates the
/// application bundle it contains.
///
/// Zip archives are extracted with `ditto`; disk images are mounted read-only
/// with `hdiutil`, the application is copied out, and the image is detached. In
/// both cases the extracted application is left in a fresh subdirectory of the
/// working directory and returned to the caller, and everything is cleaned up on
/// failure. This runs command-line tools, so it must never run inside a sandbox.
public struct ArchiveExtractor: ArchiveExtracting
{
    /// The `ditto` executable.
    private static let ditto = URL( fileURLWithPath: "/usr/bin/ditto" )

    /// The `hdiutil` executable.
    private static let hdiutil = URL( fileURLWithPath: "/usr/bin/hdiutil" )

    /// Creates an archive extractor.
    public init()
    {}

    /// Extracts an archive and returns the application bundle it contains.
    ///
    /// - Parameters:
    ///   - archive:          A file URL to the downloaded archive.
    ///   - format:           The archive's format.
    ///   - workingDirectory: A directory the extraction may write into. Defaults
    ///                       to the system temporary directory.
    ///
    /// - Returns: A file URL to the extracted `.app` bundle, under a fresh
    ///   subdirectory of `workingDirectory`.
    ///
    /// - Throws: An ``ArchiveExtractionError`` if the archive cannot be unpacked or
    ///   does not contain exactly one application.
    public func extractApplication( from archive: URL, format: UpdateArchiveFormat, into workingDirectory: URL = FileManager.default.temporaryDirectory ) async throws -> URL
    {
        let container = workingDirectory.appendingPathComponent( UUID().uuidString, isDirectory: true )

        try FileManager.default.createDirectory( at: container, withIntermediateDirectories: true )

        do
        {
            switch format
            {
                case .zip: return try await self.extractZip( archive, into: container )
                case .dmg: return try await self.extractDiskImage( archive, into: container )
            }
        }
        catch
        {
            try? FileManager.default.removeItem( at: container )

            throw error
        }
    }

    /// Extracts a zip archive into a directory and locates its application.
    ///
    /// - Parameters:
    ///   - archive:   The zip archive to extract.
    ///   - container: The directory to extract into.
    ///
    /// - Returns: The extracted application bundle.
    private func extractZip( _ archive: URL, into container: URL ) async throws -> URL
    {
        let destination = container.appendingPathComponent( "extracted", isDirectory: true )

        try FileManager.default.createDirectory( at: destination, withIntermediateDirectories: true )
        try await self.run( ArchiveExtractor.ditto, arguments: [ "-x", "-k", archive.path, destination.path ] )

        return try ArchiveExtractor.application( in: destination )
    }

    /// Mounts a disk image, copies its application out, and detaches the image.
    ///
    /// The image is detached on every path. If locating or copying the application
    /// fails, the detach is attempted and the original error is rethrown. If the
    /// copy succeeds but the detach then fails, the successfully extracted
    /// application is still returned (the detach is best-effort), rather than
    /// discarding a valid result over a lingering read-only mount.
    ///
    /// - Parameters:
    ///   - archive:   The disk image to mount.
    ///   - container: The directory to copy the application into.
    ///
    /// - Returns: The copied application bundle.
    private func extractDiskImage( _ archive: URL, into container: URL ) async throws -> URL
    {
        let mountPoint  = container.appendingPathComponent( "mount", isDirectory: true )
        let destination = container.appendingPathComponent( "extracted", isDirectory: true )

        try FileManager.default.createDirectory( at: destination, withIntermediateDirectories: true )

        // -mountpoint assumes a single volume, which holds for app-distribution
        // disk images; a multi-volume image would fail to attach (surfaced as an
        // extraction failure, leaving nothing mounted).
        try await self.run( ArchiveExtractor.hdiutil, arguments: [ "attach", archive.path, "-readonly", "-nobrowse", "-mountpoint", mountPoint.path ] )

        do
        {
            let mounted = try ArchiveExtractor.application( in: mountPoint )
            let copied  = destination.appendingPathComponent( mounted.lastPathComponent )

            try FileManager.default.copyItem( at: mounted, to: copied )

            // Best-effort: the application is already extracted, so a detach
            // failure must not discard it.
            try? await self.detach( mountPoint )

            return copied
        }
        catch
        {
            try? await self.detach( mountPoint )

            throw error
        }
    }

    /// Detaches a mounted disk image, forcing the detach if a normal one fails.
    ///
    /// - Parameter mountPoint: The mount point to detach.
    private func detach( _ mountPoint: URL ) async throws
    {
        do
        {
            try await self.run( ArchiveExtractor.hdiutil, arguments: [ "detach", mountPoint.path ] )
        }
        catch
        {
            try await self.run( ArchiveExtractor.hdiutil, arguments: [ "detach", mountPoint.path, "-force" ] )
        }
    }

    /// Locates the single application bundle within a directory tree.
    ///
    /// Searches recursively without following symbolic links (so a disk image's
    /// `/Applications` symlink is ignored) and does not descend into `.app`
    /// bundles.
    ///
    /// - Parameter directory: The directory to search.
    ///
    /// - Returns: The single `.app` bundle found.
    ///
    /// - Throws: ``ArchiveExtractionError/applicationNotFound`` when there is none,
    ///   or ``ArchiveExtractionError/multipleApplicationsFound`` when there is more
    ///   than one.
    internal static func application( in directory: URL ) throws -> URL
    {
        let applications = try ArchiveExtractor.applications( in: directory )

        guard let application = applications.first
        else
        {
            throw ArchiveExtractionError.applicationNotFound
        }

        guard applications.count == 1
        else
        {
            throw ArchiveExtractionError.multipleApplicationsFound
        }

        return application
    }

    /// Collects every application bundle within a directory tree.
    ///
    /// - Parameter directory: The directory to search.
    ///
    /// - Returns: The `.app` bundles found, in no particular order.
    private static func applications( in directory: URL ) throws -> [ URL ]
    {
        let keys     = Set<URLResourceKey>( [ .isDirectoryKey, .isSymbolicLinkKey ] )
        let contents = try FileManager.default.contentsOfDirectory( at: directory, includingPropertiesForKeys: Array( keys ), options: [ .skipsHiddenFiles ] )

        return try contents.reduce( into: [ URL ]() )
        {
            result, url in

            let values = try url.resourceValues( forKeys: keys )

            if values.isSymbolicLink == true
            {
                return
            }

            guard values.isDirectory == true
            else
            {
                return
            }

            if url.pathExtension == "app"
            {
                result.append( url )
            }
            else
            {
                result.append( contentsOf: try ArchiveExtractor.applications( in: url ) )
            }
        }
    }

    /// Runs a command-line tool and waits for it to finish.
    ///
    /// The blocking process work runs on a global dispatch queue — which is sized
    /// for blocking work — rather than the cooperative thread pool, bridged back
    /// to `async` with a continuation. Standard error is drained concurrently with
    /// execution (avoiding a full-pipe deadlock) and used as the failure reason on
    /// a non-zero exit.
    ///
    /// - Parameters:
    ///   - executable: The tool to run.
    ///   - arguments:  The arguments to pass.
    ///
    /// - Throws: ``ArchiveExtractionError/extractionFailed(reason:)`` if the tool
    ///   cannot be launched or exits with a non-zero status.
    private func run( _ executable: URL, arguments: [ String ] ) async throws
    {
        try await withCheckedThrowingContinuation
        {
            ( continuation: CheckedContinuation<Void, Error> ) in

            DispatchQueue.global( qos: .userInitiated ).async
            {
                let process           = Process()
                process.executableURL = executable
                process.arguments     = arguments

                let errorPipe          = Pipe()
                process.standardError  = errorPipe
                process.standardOutput = FileHandle.nullDevice

                do
                {
                    try process.run()
                }
                catch
                {
                    continuation.resume( throwing: ArchiveExtractionError.extractionFailed( reason: "Unable to run \( executable.lastPathComponent ): \( error.localizedDescription )" ) )

                    return
                }

                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

                process.waitUntilExit()

                guard process.terminationStatus == 0
                else
                {
                    let message = String( data: errorData, encoding: .utf8 )?.trimmingCharacters( in: .whitespacesAndNewlines ) ?? ""

                    continuation.resume( throwing: ArchiveExtractionError.extractionFailed( reason: message.isEmpty ? "\( executable.lastPathComponent ) exited with status \( process.terminationStatus )." : message ) )

                    return
                }

                continuation.resume()
            }
        }
    }
}
