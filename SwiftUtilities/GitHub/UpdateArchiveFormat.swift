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

/// A release-asset archive format supported by the in-app update path.
///
/// In-app installation can only unpack the formats listed here. A release whose
/// downloadable asset is not one of them is ineligible for in-app update, and
/// the updater falls back to the link behavior (see
/// ``GitHubUpdater/behavior``). Installer packages (`.pkg`) are intentionally
/// out of scope.
///
/// This is a pure value type used to gate in-app eligibility from an asset's
/// filename or URL, so it lives in the platform-agnostic layer alongside
/// ``UpdateCheckResult`` and ``UpdateBehavior``.
public enum UpdateArchiveFormat: Sendable, Equatable, CaseIterable
{
    /// A Zip archive (`.zip`), extracted with `ditto`.
    case zip

    /// An Apple disk image (`.dmg`), mounted with `hdiutil`.
    case dmg

    /// The lowercased file extension that identifies the format.
    ///
    /// Used both to detect a format from an asset and to describe it. Matching is
    /// always performed case-insensitively.
    public var fileExtension: String
    {
        switch self
        {
            case .zip: return "zip"
            case .dmg: return "dmg"
        }
    }

    /// Detects the archive format from a file extension.
    ///
    /// Matching is case-insensitive. Returns `nil` when the extension does not
    /// correspond to a supported format.
    ///
    /// - Parameter fileExtension: The extension to match, without a leading dot
    ///   (for example `"zip"`).
    public init?( fileExtension: String )
    {
        let normalized = fileExtension.lowercased()

        guard let format = UpdateArchiveFormat.allCases.first( where: { $0.fileExtension == normalized } )
        else
        {
            return nil
        }

        self = format
    }

    /// Detects the archive format from a filename.
    ///
    /// Uses the filename's path extension, matched case-insensitively. Returns
    /// `nil` for filenames with no extension or with an unsupported one.
    ///
    /// - Parameter filename: The asset's filename (for example `"App.zip"`).
    public init?( filename: String )
    {
        self.init( fileExtension: ( filename as NSString ).pathExtension )
    }

    /// Detects the archive format from a URL.
    ///
    /// Uses the URL's path extension, matched case-insensitively. Returns `nil`
    /// when the URL's last path component has no extension or an unsupported one.
    ///
    /// - Parameter url: The asset's download URL.
    public init?( url: URL )
    {
        self.init( fileExtension: url.pathExtension )
    }
}
