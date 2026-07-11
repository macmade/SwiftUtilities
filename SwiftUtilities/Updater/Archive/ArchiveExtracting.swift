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

/// Unpacks a downloaded update archive and locates the application it contains.
///
/// This is the dependency-injection seam for the extraction building block, so
/// the installers that compose it can be exercised with a stub in place of the
/// real ``ArchiveExtractor``. Implementations run off the sandbox (in the app for
/// non-sandboxed builds, or in the privileged helper otherwise), so they may use
/// command-line tools freely.
public protocol ArchiveExtracting: Sendable
{
    /// Extracts an archive and returns the application bundle it contains.
    ///
    /// - Parameters:
    ///   - archive:          A file URL to the downloaded archive.
    ///   - format:           The archive's format.
    ///   - workingDirectory: A directory the extraction may write into. The
    ///                       returned application lives under it and is owned by
    ///                       the caller.
    ///
    /// - Returns: A file URL to the extracted `.app` bundle.
    ///
    /// - Throws: An ``ArchiveExtractionError`` if the archive cannot be unpacked or
    ///   does not contain exactly one application.
    func extractApplication( from archive: URL, format: UpdateArchiveFormat, into workingDirectory: URL ) async throws -> URL
}
