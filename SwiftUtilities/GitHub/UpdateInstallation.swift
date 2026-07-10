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

/// The in-app install composition: extract → validate → replace → relaunch.
///
/// This runs inside the bundled updater XPC service (off the sandbox), not in the
/// app, so it can perform the privileged file operations and relaunch. It composes
/// the building blocks in a security-first order: **extract** the archive,
/// **validate** the extracted application's code signature against the running
/// application, **replace** the application on disk, then **relaunch**. Validation
/// runs on the exact bundle about to be installed, and replacement is refused
/// unless validation succeeds, so an unsigned or mismatched download is never
/// written into place.
///
/// Every step is an injected building block, so the composition and its
/// refuse-on-failure decision logic are unit-testable with stubs. The concrete
/// relaunch (the process that must outlive the app to reopen it) is supplied by
/// the service in a later milestone.
public struct UpdateInstallation: UpdateInstaller
{
    /// Unpacks the archive and locates the application.
    private let extractor: ArchiveExtracting

    /// Validates the extracted application's code signature.
    private let validator: CodeSignatureValidator

    /// Replaces the application on disk.
    private let replacer: AppReplacing

    /// Relaunches the application after the current process exits.
    private let relauncher: ApplicationRelaunching

    /// Creates an installation from its building blocks.
    ///
    /// - Parameters:
    ///   - extractor:  Unpacks the archive and locates the application.
    ///   - validator:  Validates the extracted application's code signature.
    ///   - replacer:   Replaces the application on disk.
    ///   - relauncher: Relaunches the application.
    public init( extractor: ArchiveExtracting, validator: CodeSignatureValidator, replacer: AppReplacing, relauncher: ApplicationRelaunching )
    {
        self.extractor  = extractor
        self.validator  = validator
        self.replacer   = replacer
        self.relauncher = relauncher
    }

    /// Installs a downloaded update.
    ///
    /// - Parameters:
    ///   - archive:          A file URL to the downloaded archive.
    ///   - format:           The archive's format.
    ///   - target:           A file URL to the application bundle to replace.
    ///   - workingDirectory: A fallback directory the installation may write into
    ///                       while unpacking, used only when a same-volume
    ///                       item-replacement directory for `target` cannot be
    ///                       created. Defaults to the system temporary directory.
    ///   - progress:         Invoked as each ``InstallProgress`` phase begins.
    ///                       Defaults to ignoring progress.
    ///
    /// - Throws: An error if any step fails; on a validation failure the
    ///   application on disk is left untouched.
    public func install( archive: URL, format: UpdateArchiveFormat, replacing target: URL, into workingDirectory: URL = FileManager.default.temporaryDirectory, progress: @Sendable ( InstallProgress ) -> Void = { _ in } ) async throws
    {
        let work = try self.makeWorkingDirectory( for: target, fallback: workingDirectory )

        defer
        {
            try? FileManager.default.removeItem( at: work )
        }

        progress( .extracting )

        let candidate = try await self.extractor.extractApplication( from: archive, format: format, into: work )

        progress( .validating )

        try self.validator.validate( candidateAt: candidate )

        progress( .replacing )

        let installed = try self.replacer.replaceApplication( at: target, with: candidate )

        progress( .relaunching )

        try self.relauncher.relaunch( installed )
    }

    /// Creates the directory the update is unpacked into.
    ///
    /// Prefers a system item-replacement directory on the same volume as `target`,
    /// so the replacement is an atomic rename rather than a cross-volume copy. Only
    /// if that cannot be created does it fall back to a fresh subdirectory of
    /// `fallback`.
    ///
    /// - Parameters:
    ///   - target:   The application bundle that will be replaced.
    ///   - fallback: The directory to use when a same-volume directory is unavailable.
    ///
    /// - Returns: The created working directory.
    private func makeWorkingDirectory( for target: URL, fallback: URL ) throws -> URL
    {
        if let sameVolume = try? FileManager.default.url( for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: target, create: true )
        {
            return sameVolume
        }

        let directory = fallback.appendingPathComponent( UUID().uuidString, isDirectory: true )

        try FileManager.default.createDirectory( at: directory, withIntermediateDirectories: true )

        return directory
    }
}
