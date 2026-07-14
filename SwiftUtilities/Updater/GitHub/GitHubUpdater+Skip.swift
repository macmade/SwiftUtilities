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

extension GitHubUpdater
{
    /// Determines whether an available update should still be presented, given
    /// the version the user has chosen to skip.
    ///
    /// The update is suppressed only when a skipped version is stored *and* the
    /// available update is not strictly newer than it — so re-offering the same
    /// (or an older) version stays silent, while a strictly newer version
    /// supersedes the skip and is shown again. When no version has been skipped,
    /// the update is always presented.
    ///
    /// This mirrors Sparkle's "Skip This Version" behavior and reuses the
    /// module's numeric version comparison (``isVersion(_:newerThan:)``), so a
    /// version such as `1.10` is correctly treated as newer than `1.9`.
    ///
    /// - Parameters:
    ///   - update:         The available update's version.
    ///   - skippedVersion: The version the user chose to skip, or `nil` if none.
    ///
    /// - Returns: `true` if the update should be presented, otherwise `false`.
    internal static func shouldPresentUpdate( _ update: String, skippedVersion: String? ) -> Bool
    {
        guard let skippedVersion
        else
        {
            return true
        }

        return GitHubUpdater.isVersion( update, newerThan: skippedVersion )
    }
}
