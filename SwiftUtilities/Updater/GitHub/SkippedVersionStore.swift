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

/// Persists the single update version the user has chosen to skip for a given
/// GitHub repository.
///
/// The store keeps at most one skipped version per repository, backed by
/// `UserDefaults`. Skipping a new version replaces any previously stored one:
/// the updater's rule that a strictly newer version supersedes the skip (see
/// ``GitHubUpdater/shouldPresentUpdate(_:skippedVersion:)``) makes a single
/// stored value sufficient.
///
/// The key is namespaced per repository — `"GitHubUpdater.<owner>/<repository>.skippedVersion"`
/// — so multiple updaters hosted in the same application do not clobber one
/// another. The backing `UserDefaults` is injectable, so the behavior can be
/// exercised in tests without touching the shared, process-wide defaults.
public struct SkippedVersionStore
{
    /// The `UserDefaults` key under which the skipped version is stored.
    ///
    /// Namespaced per repository, so distinct repositories keep independent
    /// skipped versions within the same defaults domain.
    public let key: String

    /// The backing defaults the skipped version is read from and written to.
    private let defaults: UserDefaults

    /// Creates a store for a repository's skipped version.
    ///
    /// - Parameters:
    ///   - owner:      The owner (user or organization) of the repository.
    ///   - repository: The name of the repository.
    ///   - defaults:   The backing `UserDefaults`. Defaults to ``UserDefaults/standard``.
    public init( owner: String, repository: String, defaults: UserDefaults = .standard )
    {
        self.key      = "GitHubUpdater.\( owner )/\( repository ).skippedVersion"
        self.defaults = defaults
    }

    /// The version the user has chosen to skip, or `nil` if none is stored.
    public var skippedVersion: String?
    {
        self.defaults.string( forKey: self.key )
    }

    /// Records a version as skipped, replacing any previously stored one.
    ///
    /// - Parameter version: The version to skip.
    public func setSkippedVersion( _ version: String )
    {
        self.defaults.set( version, forKey: self.key )
    }

    /// Clears any stored skipped version.
    public func clearSkippedVersion()
    {
        self.defaults.removeObject( forKey: self.key )
    }
}
