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

/// Replaces an application bundle on disk using `FileManager`'s safe-replace.
///
/// Uses `replaceItemAt(_:withItemAt:...)`, which swaps the replacement into the
/// original's place atomically when both are on the same volume (falling back to
/// a copy otherwise). The replacement is expected to be in a temporary location,
/// as its documentation requires; it is moved into place and no longer exists at
/// its original location afterwards. This works even when the target is the
/// running application: the running process keeps the old bundle open while the
/// on-disk bundle is replaced.
public struct AppReplacer: AppReplacing
{
    /// Creates an application replacer.
    public init()
    {}

    /// Replaces the application bundle at `target` with the one at `replacement`.
    ///
    /// - Parameters:
    ///   - target:      A file URL to the application bundle to replace.
    ///   - replacement: A file URL to the application bundle to install.
    ///
    /// - Returns: The URL of the installed application, which the OS may relocate;
    ///   it falls back to `target` when no resulting URL is reported.
    ///
    /// - Throws: An error if the replacement cannot be performed.
    public func replaceApplication( at target: URL, with replacement: URL ) throws -> URL
    {
        let resultingURL = try FileManager.default.replaceItemAt( target, withItemAt: replacement, backupItemName: nil, options: [] )
        let installed    = resultingURL ?? target

        AppReplacer.removeQuarantine( from: installed )

        return installed
    }

    /// Recursively removes the `com.apple.quarantine` attribute from a bundle.
    ///
    /// A downloaded archive carries this attribute, and macOS then refuses to
    /// `posix_spawn` any quarantined executable (with `EPERM`) and prompts Gatekeeper
    /// when opening the app. The in-place relaunch spawns one of the bundle's own
    /// executables — the updater service — so a quarantined install cannot relaunch
    /// at all, and the reopened app would be gated. The updater has already validated
    /// the download's code signature against the running application's identity (same
    /// signing identifier and Team ID) before this replacement runs, so clearing the
    /// attribute on the verified, same-developer update is safe and is what makes the
    /// installed app immediately runnable. Files without the attribute are left
    /// untouched.
    ///
    /// - Parameter url: The installed bundle to clear.
    static func removeQuarantine( from url: URL )
    {
        let attribute = "com.apple.quarantine"

        removexattr( url.path, attribute, XATTR_NOFOLLOW )

        guard let enumerator = FileManager.default.enumerator( at: url, includingPropertiesForKeys: nil )
        else
        {
            return
        }

        for case let item as URL in enumerator
        {
            removexattr( item.path, attribute, XATTR_NOFOLLOW )
        }
    }
}
