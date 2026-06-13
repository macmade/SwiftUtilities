/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2025, Jean-David Gadina - www.xs-labs.com
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

/// Checks a GitHub repository's releases and determines whether a newer
/// version of the running application is available.
///
/// The updater queries the repository's `releases` endpoint, compares the
/// newest published release against the running application's version (read
/// from its `Info.plist`), and reports the outcome as an ``UpdateCheckResult``.
/// `v`-prefixed tags are normalized before comparison, and drafts and
/// pre-releases are ignored.
///
/// ``performUpdateCheck()`` is platform-agnostic and returns a value. On
/// platforms where AppKit is available, ``checkForUpdates()`` and
/// ``checkForUpdatesInBackground()`` present the result to the user as an
/// `NSAlert`.
public final class GitHubUpdater: Sendable
{
    /// The type of the closure used to fetch the data for a request.
    public typealias Fetcher = @Sendable ( URLRequest ) async throws -> ( Data, URLResponse )
    
    /// The owner (user or organization) of the GitHub repository.
    public let owner:      String

    /// The name of the GitHub repository.
    public let repository: String

    /// The GitHub API URL of the repository's releases endpoint.
    public let url:        URL

    /// The running application's version, captured from its `Info.plist`.
    let currentVersion:    String?

    /// The running application's display name, captured from its `Info.plist`.
    let programName:       String?

    /// The closure used to fetch the releases data.
    let fetch:             Fetcher

    /// Creates an updater for the given GitHub repository.
    ///
    /// The running application's name and version are read from its `Info.plist`,
    /// and releases are fetched through the shared `URLSession`.
    ///
    /// - Parameters:
    ///   - owner:      The owner (user or organization) of the repository.
    ///   - repository: The name of the repository.
    ///
    /// - Returns: `nil` if a valid releases URL cannot be built from the supplied values.
    public convenience init?( owner: String, repository: String )
    {
        self.init(
            owner:          owner,
            repository:     repository,
            currentVersion: Bundle.main.object( forInfoDictionaryKey: "CFBundleShortVersionString" ) as? String,
            programName:    Bundle.main.object( forInfoDictionaryKey: "CFBundleName" ) as? String,
            fetch:          { try await URLSession.shared.data( for: $0 ) }
        )
    }

    /// Creates an updater with explicit dependencies.
    ///
    /// This initializer is the test seam for the update-check orchestration: it
    /// allows the current version, application name, and the fetching of release
    /// data to be supplied directly, so the decision logic can be exercised
    /// without `Bundle.main` or the network.
    ///
    /// - Parameters:
    ///   - owner:          The owner (user or organization) of the repository.
    ///   - repository:     The name of the repository.
    ///   - currentVersion: The running application's version, or `nil` if unknown.
    ///   - programName:    The running application's display name, or `nil` if unknown.
    ///   - fetch:          The closure used to fetch the releases data.
    ///
    /// - Returns: `nil` if a valid releases URL cannot be built from the supplied values.
    init?( owner: String, repository: String, currentVersion: String?, programName: String?, fetch: @escaping Fetcher )
    {
        guard let url = URL( string: "https://api.github.com/repos/\( owner )/\( repository )/releases" )
        else
        {
            return nil
        }

        self.owner          = owner
        self.repository     = repository
        self.url            = url
        self.currentVersion = currentVersion
        self.programName    = programName
        self.fetch          = fetch
    }

    /// Fetches the repository's releases and determines whether an update is available.
    ///
    /// Uses the application name and version captured at initialization, fetches
    /// and parses the releases, and compares the newest published release against
    /// the current version.
    ///
    /// This method performs no UI work; it returns the outcome as an
    /// ``UpdateCheckResult`` for the caller to handle.
    ///
    /// - Returns: The outcome of the update check.
    public func performUpdateCheck() async -> UpdateCheckResult
    {
        guard let current = self.currentVersion,
              let program = self.programName
        else
        {
            return .failed( reason: "Unable to determine current version." )
        }

        let data:     Data
        let response: URLResponse

        do
        {
            ( data, response ) = try await self.fetch( self.makeRequest() )
        }
        catch
        {
            return .failed( reason: "Unable to fetch release information from GitHub: \( error.localizedDescription )" )
        }

        if let status = ( response as? HTTPURLResponse )?.statusCode, ( 200 ..< 300 ).contains( status ) == false
        {
            if status == 403 || status == 429
            {
                return .failed( reason: "GitHub rate limit reached. Please try again later." )
            }

            return .failed( reason: "Unable to fetch release information from GitHub (HTTP \( status ))." )
        }

        guard let releases = GitHubUpdater.parseReleases( from: data )
        else
        {
            return .failed( reason: "Unable to parse release information from GitHub." )
        }

        return GitHubUpdater.updateCheckResult( current: current, program: program, releases: releases )
    }

    /// Builds the request used to fetch the repository's releases.
    ///
    /// Sets the headers recommended by GitHub's REST API: a `User-Agent`
    /// (required — requests without one are rejected), an explicit `Accept`
    /// of `application/vnd.github+json`, and a pinned `X-GitHub-Api-Version`
    /// so the response format does not shift unexpectedly.
    ///
    /// - Returns: The configured request for ``url``.
    func makeRequest() -> URLRequest
    {
        var request = URLRequest( url: self.url )

        request.setValue( self.programName ?? "\( self.owner )/\( self.repository )", forHTTPHeaderField: "User-Agent" )
        request.setValue( "application/vnd.github+json",                              forHTTPHeaderField: "Accept" )
        request.setValue( "2022-11-28",                                               forHTTPHeaderField: "X-GitHub-Api-Version" )

        return request
    }

    /// Determines the update-check outcome for a set of parsed releases.
    ///
    /// Compares the newest release (the first element, as ``parseReleases(from:)``
    /// returns them newest-first) against the current version and produces the
    /// corresponding ``UpdateCheckResult``. This is pure: it performs no network
    /// or UI work.
    ///
    /// - Parameters:
    ///   - current:  The running application's version.
    ///   - program:  The display name of the application.
    ///   - releases: The parsed releases, sorted newest-first.
    ///
    /// - Returns: ``UpdateCheckResult/upToDate(application:version:)`` when no
    ///            newer release exists, ``UpdateCheckResult/updateAvailable(application:version:update:url:)``
    ///            when one does, or ``UpdateCheckResult/failed(reason:)`` if the
    ///            release URL cannot be parsed.
    static func updateCheckResult( current: String, program: String, releases: [ ( version: String, url: String ) ] ) -> UpdateCheckResult
    {
        guard let latest = releases.first
        else
        {
            return .upToDate( application: program, version: current )
        }

        guard GitHubUpdater.isVersion( latest.version, newerThan: current )
        else
        {
            return .upToDate( application: program, version: current )
        }

        guard let url = URL( string: latest.url )
        else
        {
            return .failed( reason: "Unable to parse release URL." )
        }

        return .updateAvailable( application: program, version: current, update: latest.version, url: url )
    }

    /// Normalizes a version string for comparison.
    ///
    /// Trims surrounding whitespace and removes a leading `v` or `V`, so that
    /// tags such as `"v1.2.3"` compare equal to bundle versions such as `"1.2.3"`.
    ///
    /// - Parameter version: The raw version string to normalize.
    ///
    /// - Returns: The normalized version string.
    private static func normalizedVersion( _ version: String ) -> String
    {
        let trimmed = version.trimmingCharacters( in: .whitespacesAndNewlines )

        if trimmed.first == "v" || trimmed.first == "V"
        {
            return String( trimmed.dropFirst() )
        }

        return trimmed
    }

    /// Returns whether one version string represents a newer version than another.
    ///
    /// Both values are normalized with ``normalizedVersion(_:)`` and compared
    /// numerically, so segments are ordered by value (for example `1.10` is newer
    /// than `1.9`).
    ///
    /// - Parameters:
    ///   - version: The version to test.
    ///   - other:   The version to compare against.
    ///
    /// - Returns: `true` if `version` is strictly newer than `other`, otherwise `false`.
    static func isVersion( _ version: String, newerThan other: String ) -> Bool
    {
        GitHubUpdater.normalizedVersion( version ).compare( GitHubUpdater.normalizedVersion( other ), options: .numeric ) == .orderedDescending
    }

    /// Parses the JSON payload of the GitHub releases endpoint.
    ///
    /// Decodes the array of releases, discards drafts, pre-releases, and entries
    /// missing a `tag_name` or `html_url`, and returns the remaining releases
    /// sorted newest-first.
    ///
    /// - Parameter data: The raw JSON data returned by the releases endpoint.
    ///
    /// - Returns: The parsed releases sorted from newest to oldest, or `nil` if the
    ///            data is not a JSON array of release objects.
    static func parseReleases( from data: Data ) -> [ ( version: String, url: String ) ]?
    {
        guard let releases = try? JSONSerialization.jsonObject( with: data ) as? [ [ String: Any ] ]
        else
        {
            return nil
        }

        return releases.compactMap
        {
            guard let version = $0[ "tag_name" ] as? String,
                  let url     = $0[ "html_url" ] as? String
            else
            {
                return nil
            }

            if $0[ "draft" ] as? Bool == true || $0[ "prerelease" ] as? Bool == true
            {
                return nil
            }

            return ( version: version, url: url )
        }
        .sorted
        {
            GitHubUpdater.isVersion( $0.version, newerThan: $1.version )
        }
    }
}
