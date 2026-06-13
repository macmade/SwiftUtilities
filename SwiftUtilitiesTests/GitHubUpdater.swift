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
@testable import SwiftUtilities
import Testing

struct Test_GitHubUpdater
{
    @Test
    func initialize() async throws
    {
        let updater = GitHubUpdater( owner: "apple", repository: "swift" )

        #expect( updater                     != nil )
        #expect( updater?.owner              == "apple" )
        #expect( updater?.repository         == "swift" )
        #expect( updater?.url.absoluteString == "https://api.github.com/repos/apple/swift/releases" )
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
}
