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

    struct Test_GitHubUpdaterBehavior
    {
        // `updateWindowMode` is the in-app routing seam, gated out of the SwiftPM
        // build; these tests only run in the Xcode framework build.
        #if !SWIFT_PACKAGE

        @Test
        func linkBehaviorSelectsLinkModeRegardlessOfDownload() async throws
        {
            let url = try #require( URL( string: "https://example.com/app.zip" ) )

            #expect( GitHubUpdater.updateWindowMode( for: .link, downloadURL: url, serviceAvailable: true )  == .link )
            #expect( GitHubUpdater.updateWindowMode( for: .link, downloadURL: nil, serviceAvailable: true )  == .link )
        }

        @Test
        func inAppBehaviorSelectsInAppModeWhenDownloadAvailable() async throws
        {
            let url = try #require( URL( string: "https://example.com/app.zip" ) )

            #expect( GitHubUpdater.updateWindowMode( for: .inApp, downloadURL: url, serviceAvailable: true ) == .inApp )
        }

        @Test
        func inAppBehaviorFallsBackToLinkWhenNoDownload() async throws
        {
            #expect( GitHubUpdater.updateWindowMode( for: .inApp, downloadURL: nil, serviceAvailable: true ) == .link )
        }

        @Test
        func inAppBehaviorFallsBackToLinkForUnsupportedArchive() async throws
        {
            let pkg = try #require( URL( string: "https://example.com/app.pkg" ) )

            #expect( GitHubUpdater.updateWindowMode( for: .inApp, downloadURL: pkg, serviceAvailable: true ) == .link )
        }

        @Test
        func inAppBehaviorSelectsInAppModeForDmg() async throws
        {
            let dmg = try #require( URL( string: "https://example.com/app.dmg" ) )

            #expect( GitHubUpdater.updateWindowMode( for: .inApp, downloadURL: dmg, serviceAvailable: true ) == .inApp )
        }

        @Test
        func inAppBehaviorFallsBackToLinkWhenServiceUnavailable() async throws
        {
            let url = try #require( URL( string: "https://example.com/app.zip" ) )

            // The SwiftPM distribution carries no bundled service, so a supported
            // in-app request must still fall back to the link window.
            #expect( GitHubUpdater.updateWindowMode( for: .inApp, downloadURL: url, serviceAvailable: false ) == .link )
        }

        #endif

        @Test
        func behaviorDefaultsToLinkAtConstruction() async throws
        {
            let updater = try #require( GitHubUpdater( owner: "apple", repository: "swift" ) )

            #expect( updater.behavior == .link )
        }

        @Test
        func behaviorReflectsConstructionValue() async throws
        {
            let updater = try #require( GitHubUpdater( owner: "apple", repository: "swift", behavior: .inApp ) )

            #expect( updater.behavior == .inApp )
        }
    }

#endif
