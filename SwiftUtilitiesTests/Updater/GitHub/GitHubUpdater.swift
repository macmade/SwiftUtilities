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
@testable import SwiftUtilities
import Testing

struct Test_GitHubUpdater
{
    /// The shape of a single parsed release, mirroring the tuple returned by
    /// ``GitHubUpdater/parseReleases(from:)`` and consumed by
    /// ``GitHubUpdater/updateCheckResult(current:program:releases:)``.
    private typealias ParsedRelease = ( version: String, notes: String, url: String, downloadURL: String? )

    @Test
    func initialize() async throws
    {
        let updater = GitHubUpdater( owner: "apple", repository: "swift" )

        #expect( updater                     != nil )
        #expect( updater?.owner              == "apple" )
        #expect( updater?.repository         == "swift" )
        #expect( updater?.url.absoluteString == "https://api.github.com/repos/apple/swift/releases?per_page=100" )
    }

    @Test
    func isVersionNewer() async throws
    {
        #expect( GitHubUpdater.isVersion( "1.2.3", newerThan: "1.2.2" ) == true )
        #expect( GitHubUpdater.isVersion( "1.2.2", newerThan: "1.2.3" ) == false )
        #expect( GitHubUpdater.isVersion( "1.2.3", newerThan: "1.2.3" ) == false )
    }

    @Test
    func isVersionNewerNumericOrdering() async throws
    {
        #expect( GitHubUpdater.isVersion( "1.10.0", newerThan: "1.9.0"  ) == true )
        #expect( GitHubUpdater.isVersion( "1.9.0",  newerThan: "1.10.0" ) == false )
    }

    @Test
    func isVersionNewerIgnoresPrefixAndWhitespace() async throws
    {
        #expect( GitHubUpdater.isVersion( "v1.2.3",  newerThan: "1.2.3"  ) == false )
        #expect( GitHubUpdater.isVersion( "1.2.3",   newerThan: "v1.2.3" ) == false )
        #expect( GitHubUpdater.isVersion( "v1.2.4",  newerThan: "v1.2.3" ) == true )
        #expect( GitHubUpdater.isVersion( " 1.2.4 ", newerThan: "1.2.3"  ) == true )
    }

    @Test
    func parseReleasesSortsNewestFirst() async throws
    {
        let json = """
            [
                { "tag_name": "v1.0.0", "html_url": "https://example.com/1.0.0" },
                { "tag_name": "v1.2.0", "html_url": "https://example.com/1.2.0" },
                { "tag_name": "v1.1.0", "html_url": "https://example.com/1.1.0" }
            ]
            """

        let releases = try #require( GitHubUpdater.parseReleases( from: Data( json.utf8 ) ) )

        #expect( releases.count          == 3 )
        #expect( releases.first?.version == "v1.2.0" )
        #expect( releases.first?.url     == "https://example.com/1.2.0" )
        #expect( releases.last?.version  == "v1.0.0" )
    }

    @Test
    func parseReleasesSkipsEntriesMissingFields() async throws
    {
        let json = """
            [
                { "tag_name": "v1.0.0", "html_url": "https://example.com/1.0.0" },
                { "tag_name": "v1.1.0" },
                { "html_url": "https://example.com/orphan" }
            ]
            """

        let releases = try #require( GitHubUpdater.parseReleases( from: Data( json.utf8 ) ) )

        #expect( releases.count          == 1 )
        #expect( releases.first?.version == "v1.0.0" )
    }

    @Test
    func parseReleasesSkipsDraftsAndPreReleases() async throws
    {
        let json = """
            [
                { "tag_name": "v1.0.0", "html_url": "https://example.com/1.0.0", "draft": false, "prerelease": false },
                { "tag_name": "v2.0.0", "html_url": "https://example.com/2.0.0", "draft": true,  "prerelease": false },
                { "tag_name": "v3.0.0", "html_url": "https://example.com/3.0.0", "draft": false, "prerelease": true }
            ]
            """

        let releases = try #require( GitHubUpdater.parseReleases( from: Data( json.utf8 ) ) )

        #expect( releases.count          == 1 )
        #expect( releases.first?.version == "v1.0.0" )
    }

    @Test
    func parseReleasesReturnsNilForInvalidJSON() async throws
    {
        #expect( GitHubUpdater.parseReleases( from: Data( "not json".utf8 ) ) == nil )
    }

    @Test
    func parseReleasesReturnsEmptyForEmptyArray() async throws
    {
        let releases = try #require( GitHubUpdater.parseReleases( from: Data( "[]".utf8 ) ) )

        #expect( releases.isEmpty )
    }

    @Test
    func parseReleasesCapturesNotesAndFirstAssetDownloadURL() async throws
    {
        let json = """
            [
                {
                    "tag_name":  "v1.0.0",
                    "html_url":  "https://example.com/1.0.0",
                    "body":      "## What's New\\n- Faster startup",
                    "assets":    [
                        { "browser_download_url": "https://example.com/download/app.zip" },
                        { "browser_download_url": "https://example.com/download/other.zip" }
                    ]
                }
            ]
            """

        let releases = try #require( GitHubUpdater.parseReleases( from: Data( json.utf8 ) ) )

        #expect( releases.first?.notes       == "## What's New\n- Faster startup" )
        #expect( releases.first?.downloadURL == "https://example.com/download/app.zip" )
    }

    @Test
    func parseReleasesDefaultsNotesToEmptyWhenBodyMissing() async throws
    {
        let json = """
            [ { "tag_name": "v1.0.0", "html_url": "https://example.com/1.0.0" } ]
            """

        let releases = try #require( GitHubUpdater.parseReleases( from: Data( json.utf8 ) ) )

        #expect( releases.first?.notes == "" )
    }

    @Test
    func parseReleasesDownloadURLIsNilWhenNoAssets() async throws
    {
        let withoutKey = """
            [ { "tag_name": "v1.0.0", "html_url": "https://example.com/1.0.0" } ]
            """
        let emptyArray = """
            [ { "tag_name": "v1.0.0", "html_url": "https://example.com/1.0.0", "assets": [] } ]
            """
        let missingURL = """
            [ { "tag_name": "v1.0.0", "html_url": "https://example.com/1.0.0", "assets": [ { "name": "app.zip" } ] } ]
            """

        #expect( try #require( GitHubUpdater.parseReleases( from: Data( withoutKey.utf8 ) ) ).first?.downloadURL == nil )
        #expect( try #require( GitHubUpdater.parseReleases( from: Data( emptyArray.utf8 ) ) ).first?.downloadURL == nil )
        #expect( try #require( GitHubUpdater.parseReleases( from: Data( missingURL.utf8 ) ) ).first?.downloadURL == nil )
    }

    @Test
    func updateCheckResultReportsUpToDateWhenNoReleases() async throws
    {
        let result = GitHubUpdater.updateCheckResult( current: "1.0.0", program: "App", releases: [] )

        #expect( result == .upToDate( application: "App", version: "1.0.0" ) )
    }

    @Test
    func updateCheckResultReportsUpToDateWhenLatestIsNotNewer() async throws
    {
        let releases: [ ParsedRelease ] = [ ( version: "v1.0.0", notes: "", url: "https://example.com/1.0.0", downloadURL: nil ) ]
        let result                      = GitHubUpdater.updateCheckResult( current: "1.0.0", program: "App", releases: releases )

        #expect( result == .upToDate( application: "App", version: "1.0.0" ) )
    }

    @Test
    func updateCheckResultReportsUpdateWhenNewerAvailable() async throws
    {
        let releases: [ ParsedRelease ] = [ ( version: "v2.0.0", notes: "", url: "https://example.com/2.0.0", downloadURL: nil ) ]
        let result                      = GitHubUpdater.updateCheckResult( current: "1.0.0", program: "App", releases: releases )
        let url                         = try #require( URL( string: "https://example.com/2.0.0" ) )

        #expect( result == .updateAvailable( application: "App", version: "1.0.0", update: "v2.0.0", url: url, notes: "", downloadURL: nil ) )
    }

    @Test
    func updateCheckResultUsesNewestReleaseFirst() async throws
    {
        let releases: [ ParsedRelease ] = [
            ( version: "v3.0.0", notes: "", url: "https://example.com/3.0.0", downloadURL: nil ),
            ( version: "v2.0.0", notes: "", url: "https://example.com/2.0.0", downloadURL: nil ),
        ]
        let result = GitHubUpdater.updateCheckResult( current: "1.0.0", program: "App", releases: releases )
        let url    = try #require( URL( string: "https://example.com/3.0.0" ) )

        #expect( result == .updateAvailable( application: "App", version: "1.0.0", update: "v3.0.0", url: url, notes: "", downloadURL: nil ) )
    }

    @Test
    func updateCheckResultFailsForInvalidReleaseURL() async throws
    {
        let releases: [ ParsedRelease ] = [ ( version: "v2.0.0", notes: "", url: "", downloadURL: nil ) ]
        let result                      = GitHubUpdater.updateCheckResult( current: "1.0.0", program: "App", releases: releases )

        #expect( result == .failed( reason: "Unable to parse release URL." ) )
    }

    @Test
    func updateCheckResultPropagatesNotesAndDownloadURL() async throws
    {
        let releases: [ ParsedRelease ] = [ ( version: "v2.0.0", notes: "What's new", url: "https://example.com/2.0.0", downloadURL: "https://example.com/app.zip" ) ]
        let result                      = GitHubUpdater.updateCheckResult( current: "1.0.0", program: "App", releases: releases )
        let url                         = try #require( URL( string: "https://example.com/2.0.0" ) )
        let download                    = try #require( URL( string: "https://example.com/app.zip" ) )

        #expect( result == .updateAvailable( application: "App", version: "1.0.0", update: "v2.0.0", url: url, notes: "What's new", downloadURL: download ) )
    }

    @Test
    func updateCheckResultHasNilDownloadURLWhenAssetMissing() async throws
    {
        let releases: [ ParsedRelease ] = [ ( version: "v2.0.0", notes: "What's new", url: "https://example.com/2.0.0", downloadURL: nil ) ]
        let result                      = GitHubUpdater.updateCheckResult( current: "1.0.0", program: "App", releases: releases )
        let url                         = try #require( URL( string: "https://example.com/2.0.0" ) )

        #expect( result == .updateAvailable( application: "App", version: "1.0.0", update: "v2.0.0", url: url, notes: "What's new", downloadURL: nil ) )
    }

    private struct StubError: Error
    {}

    private func makeUpdater( currentVersion: String?, programName: String?, fetch: @escaping GitHubUpdater.Fetcher ) throws -> GitHubUpdater
    {
        try #require( GitHubUpdater( owner: "apple", repository: "swift", currentVersion: currentVersion, programName: programName, fetch: fetch ) )
    }

    private func makeFetch( status: Int, json: String, headers: [ String: String ]? = nil ) -> GitHubUpdater.Fetcher
    {
        {
            request in

            let url      = try #require( request.url )
            let response = try #require( HTTPURLResponse( url: url, statusCode: status, httpVersion: nil, headerFields: headers ) )

            return ( Data( json.utf8 ), response )
        }
    }

    private func makeResponse( status: Int, headers: [ String: String ]? = nil ) throws -> HTTPURLResponse
    {
        let url = try #require( URL( string: "https://example.com" ) )

        return try #require( HTTPURLResponse( url: url, statusCode: status, httpVersion: nil, headerFields: headers ) )
    }

    @Test
    func performUpdateCheckReportsUpToDate() async throws
    {
        let json = """
            [ { "tag_name": "v1.0.0", "html_url": "https://example.com/1.0.0" } ]
            """

        let updater = try self.makeUpdater( currentVersion: "1.0.0", programName: "App", fetch: self.makeFetch( status: 200, json: json ) )
        let result  = await updater.performUpdateCheck()

        #expect( result == .upToDate( application: "App", version: "1.0.0" ) )
    }

    @Test
    func performUpdateCheckReportsUpdateAvailable() async throws
    {
        let json = """
            [ { "tag_name": "v2.0.0", "html_url": "https://example.com/2.0.0" } ]
            """

        let updater = try self.makeUpdater( currentVersion: "1.0.0", programName: "App", fetch: self.makeFetch( status: 200, json: json ) )
        let result  = await updater.performUpdateCheck()
        let url     = try #require( URL( string: "https://example.com/2.0.0" ) )

        #expect( result == .updateAvailable( application: "App", version: "1.0.0", update: "v2.0.0", url: url, notes: "", downloadURL: nil ) )
    }

    @Test
    func performUpdateCheckCarriesNotesAndDownloadURL() async throws
    {
        let json = """
            [
                {
                    "tag_name":  "v2.0.0",
                    "html_url":  "https://example.com/2.0.0",
                    "body":      "Release notes",
                    "assets":    [ { "browser_download_url": "https://example.com/app.zip" } ]
                }
            ]
            """

        let updater  = try self.makeUpdater( currentVersion: "1.0.0", programName: "App", fetch: self.makeFetch( status: 200, json: json ) )
        let result   = await updater.performUpdateCheck()
        let url      = try #require( URL( string: "https://example.com/2.0.0" ) )
        let download = try #require( URL( string: "https://example.com/app.zip" ) )

        #expect( result == .updateAvailable( application: "App", version: "1.0.0", update: "v2.0.0", url: url, notes: "Release notes", downloadURL: download ) )
    }

    @Test
    func performUpdateCheckFailsWhenVersionUnknown() async throws
    {
        let updater = try self.makeUpdater( currentVersion: nil, programName: "App", fetch: self.makeFetch( status: 200, json: "[]" ) )
        let result  = await updater.performUpdateCheck()

        #expect( result == .failed( reason: "Unable to determine current version." ) )
    }

    @Test
    func performUpdateCheckFailsOnFetchError() async throws
    {
        let updater = try self.makeUpdater( currentVersion: "1.0.0", programName: "App" )
        {
            _ in throw StubError()
        }

        let result = await updater.performUpdateCheck()

        guard case .failed = result
        else
        {
            Issue.record( "Expected a failure result" )

            return
        }
    }

    @Test
    func performUpdateCheckReportsRateLimit() async throws
    {
        let fetch   = self.makeFetch( status: 403, json: "[]", headers: [ "X-RateLimit-Remaining": "0" ] )
        let updater = try self.makeUpdater( currentVersion: "1.0.0", programName: "App", fetch: fetch )
        let result  = await updater.performUpdateCheck()

        #expect( result == .failed( reason: "GitHub rate limit reached. Please try again later." ) )
    }

    @Test
    func performUpdateCheckReportsRateLimitOn429() async throws
    {
        let updater = try self.makeUpdater( currentVersion: "1.0.0", programName: "App", fetch: self.makeFetch( status: 429, json: "[]" ) )
        let result  = await updater.performUpdateCheck()

        #expect( result == .failed( reason: "GitHub rate limit reached. Please try again later." ) )
    }

    @Test
    func performUpdateCheckReportsForbiddenNotRateLimited() async throws
    {
        let updater = try self.makeUpdater( currentVersion: "1.0.0", programName: "App", fetch: self.makeFetch( status: 403, json: "[]" ) )
        let result  = await updater.performUpdateCheck()

        #expect( result == .failed( reason: "Unable to fetch release information from GitHub (HTTP 403)." ) )
    }

    @Test
    func performUpdateCheckReportsHTTPError() async throws
    {
        let updater = try self.makeUpdater( currentVersion: "1.0.0", programName: "App", fetch: self.makeFetch( status: 500, json: "[]" ) )
        let result  = await updater.performUpdateCheck()

        #expect( result == .failed( reason: "Unable to fetch release information from GitHub (HTTP 500)." ) )
    }

    @Test
    func performUpdateCheckFailsForNonHTTPResponse() async throws
    {
        let fetch: GitHubUpdater.Fetcher =
        {
            request in

            let url      = try #require( request.url )
            let response = URLResponse( url: url, mimeType: nil, expectedContentLength: 0, textEncodingName: nil )

            return ( Data( "[]".utf8 ), response )
        }

        let updater = try self.makeUpdater( currentVersion: "1.0.0", programName: "App", fetch: fetch )
        let result  = await updater.performUpdateCheck()

        #expect( result == .failed( reason: "Received an unexpected response from GitHub." ) )
    }

    @Test
    func performUpdateCheckReportsParseFailure() async throws
    {
        let updater = try self.makeUpdater( currentVersion: "1.0.0", programName: "App", fetch: self.makeFetch( status: 200, json: "not json" ) )
        let result  = await updater.performUpdateCheck()

        #expect( result == .failed( reason: "Unable to parse release information from GitHub." ) )
    }

    @Test
    func makeRequestSetsGitHubHeaders() async throws
    {
        let updater = try self.makeUpdater( currentVersion: "1.0.0", programName: "App", fetch: self.makeFetch( status: 200, json: "[]" ) )
        let request = updater.makeRequest()

        #expect( request.url                                                 == updater.url )
        #expect( request.cachePolicy                                         == .reloadIgnoringLocalCacheData )
        #expect( request.value( forHTTPHeaderField: "User-Agent" )           == "App" )
        #expect( request.value( forHTTPHeaderField: "Accept" )               == "application/vnd.github+json" )
        #expect( request.value( forHTTPHeaderField: "X-GitHub-Api-Version" ) == "2022-11-28" )
    }

    @Test
    func makeRequestFallsBackToRepositoryForUserAgent() async throws
    {
        let updater = try self.makeUpdater( currentVersion: "1.0.0", programName: nil, fetch: self.makeFetch( status: 200, json: "[]" ) )
        let request = updater.makeRequest()

        #expect( request.value( forHTTPHeaderField: "User-Agent" ) == "apple/swift" )
    }

    @Test
    func isRateLimitedAlwaysTrueFor429() async throws
    {
        #expect( GitHubUpdater.isRateLimited( try self.makeResponse( status: 429 ) ) == true )
    }

    @Test
    func isRateLimitedFor403WithExhaustedRemaining() async throws
    {
        let response = try self.makeResponse( status: 403, headers: [ "X-RateLimit-Remaining": "0" ] )

        #expect( GitHubUpdater.isRateLimited( response ) == true )
    }

    @Test
    func isRateLimitedFor403WithRetryAfter() async throws
    {
        let response = try self.makeResponse( status: 403, headers: [ "Retry-After": "60" ] )

        #expect( GitHubUpdater.isRateLimited( response ) == true )
    }

    @Test
    func isNotRateLimitedFor403WithRemainingRequests() async throws
    {
        let response = try self.makeResponse( status: 403, headers: [ "X-RateLimit-Remaining": "57" ] )

        #expect( GitHubUpdater.isRateLimited( response ) == false )
    }

    @Test
    func isNotRateLimitedForPlain403() async throws
    {
        #expect( GitHubUpdater.isRateLimited( try self.makeResponse( status: 403 ) ) == false )
    }

    @Test
    func isNotRateLimitedForOtherStatus() async throws
    {
        #expect( GitHubUpdater.isRateLimited( try self.makeResponse( status: 500 ) ) == false )
    }
}
