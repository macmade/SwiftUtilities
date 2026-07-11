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

/// Installs a downloaded update: unpack it, verify its signature, replace the
/// running application on disk, and arrange for a relaunch.
///
/// This is the common contract shared by the in-process installer (for
/// non-sandboxed apps) and the XPC-backed installer (for sandboxed apps). An
/// implementation must never replace the application unless the downloaded build
/// passes code-signature validation against the running application's identity.
///
/// On success the update has been staged and a relaunch scheduled; the caller is
/// then responsible for terminating the application, which triggers the
/// relaunch into the new version.
public protocol UpdateInstaller: Sendable
{
    /// Installs a downloaded update.
    ///
    /// - Parameters:
    ///   - archive:          A file URL to the downloaded archive.
    ///   - format:           The archive's format.
    ///   - target:           A file URL to the application bundle to replace
    ///                       (typically the running application).
    ///   - workingDirectory: A directory the installer may write into while
    ///                       unpacking.
    ///   - progress:         Invoked as each ``InstallProgress`` phase begins.
    ///
    /// - Throws: An error if any step fails; on a validation failure the
    ///   application on disk is left untouched.
    func install( archive: URL, format: UpdateArchiveFormat, replacing target: URL, into workingDirectory: URL, progress: @escaping @Sendable ( InstallProgress ) -> Void ) async throws
}
