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

/// The outcome of checking a GitHub repository for a newer release.
///
/// This is the value-level result of an update check, independent of any
/// presentation. Callers decide how to surface it; on platforms where AppKit
/// is available, ``GitHubUpdater`` provides convenience methods that present
/// each case as an `NSAlert`.
public enum UpdateCheckResult: Sendable, Equatable
{
    /// The running application is already on the newest available version.
    ///
    /// - Parameters:
    ///   - application: The display name of the application.
    ///   - version:     The current version of the application.
    case upToDate( application: String, version: String )

    /// A newer version is available for download.
    ///
    /// - Parameters:
    ///   - application: The display name of the application.
    ///   - version:     The current version of the application.
    ///   - update:      The version of the available update.
    ///   - url:         The URL of the release page for the update.
    ///   - notes:       The release's Markdown notes, or an empty string when the
    ///                  release has no body.
    ///   - downloadURL: The direct download URL of the release's first asset, or
    ///                  `nil` when the release has no downloadable asset.
    case updateAvailable( application: String, version: String, update: String, url: URL, notes: String, downloadURL: URL? )

    /// The update check could not be completed.
    ///
    /// - Parameter reason: A user-readable description of what went wrong.
    case failed( reason: String )
}
