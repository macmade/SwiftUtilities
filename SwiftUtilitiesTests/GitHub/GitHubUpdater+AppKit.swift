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

#if canImport( AppKit )

    import Foundation
    @testable import SwiftUtilities
    import Testing

    struct Test_GitHubUpdaterAlert
    {
        @Test
        func upToDateShownWhenOptionEnabled() async throws
        {
            let result = UpdateCheckResult.upToDate( application: "App", version: "1.0.0" )
            let alert  = GitHubUpdater.alert( for: result, messages: .upToDate )

            #expect( alert == .upToDate( application: "App", version: "1.0.0" ) )
        }

        @Test
        func upToDateSuppressedWhenOptionDisabled() async throws
        {
            let result = UpdateCheckResult.upToDate( application: "App", version: "1.0.0" )

            #expect( GitHubUpdater.alert( for: result, messages: [] )                == .none )
            #expect( GitHubUpdater.alert( for: result, messages: .updateAvailable )  == .none )
            #expect( GitHubUpdater.alert( for: result, messages: .error )            == .none )
        }

        @Test
        func updateAvailableShownWhenOptionEnabled() async throws
        {
            let url    = try #require( URL( string: "https://example.com/2.0.0" ) )
            let result = UpdateCheckResult.updateAvailable( application: "App", version: "1.0.0", update: "2.0.0", url: url, notes: "Notes", downloadURL: nil )
            let alert  = GitHubUpdater.alert( for: result, messages: .updateAvailable )

            #expect( alert == .updateAvailable( application: "App", version: "1.0.0", update: "2.0.0", url: url, notes: "Notes", downloadURL: nil ) )
        }

        @Test
        func updateAvailableSuppressedWhenOptionDisabled() async throws
        {
            let url    = try #require( URL( string: "https://example.com/2.0.0" ) )
            let result = UpdateCheckResult.updateAvailable( application: "App", version: "1.0.0", update: "2.0.0", url: url, notes: "Notes", downloadURL: nil )

            #expect( GitHubUpdater.alert( for: result, messages: [] )         == .none )
            #expect( GitHubUpdater.alert( for: result, messages: .upToDate )  == .none )
            #expect( GitHubUpdater.alert( for: result, messages: .error )     == .none )
        }

        @Test
        func errorShownWhenOptionEnabled() async throws
        {
            let result = UpdateCheckResult.failed( reason: "Boom" )
            let alert  = GitHubUpdater.alert( for: result, messages: .error )

            #expect( alert == .error( message: "Boom" ) )
        }

        @Test
        func errorSuppressedWhenOptionDisabled() async throws
        {
            let result = UpdateCheckResult.failed( reason: "Boom" )

            #expect( GitHubUpdater.alert( for: result, messages: [] )                == .none )
            #expect( GitHubUpdater.alert( for: result, messages: .upToDate )         == .none )
            #expect( GitHubUpdater.alert( for: result, messages: .updateAvailable )  == .none )
        }

        @Test
        func allOptionShowsEveryOutcome() async throws
        {
            let url = try #require( URL( string: "https://example.com/2.0.0" ) )

            #expect( GitHubUpdater.alert( for: .upToDate( application: "App", version: "1.0.0" ), messages: .all )
                == .upToDate( application: "App", version: "1.0.0" ) )

            #expect( GitHubUpdater.alert( for: .updateAvailable( application: "App", version: "1.0.0", update: "2.0.0", url: url, notes: "Notes", downloadURL: nil ), messages: .all )
                == .updateAvailable( application: "App", version: "1.0.0", update: "2.0.0", url: url, notes: "Notes", downloadURL: nil ) )

            #expect( GitHubUpdater.alert( for: .failed( reason: "Boom" ), messages: .all )
                == .error( message: "Boom" ) )
        }
    }

#endif
