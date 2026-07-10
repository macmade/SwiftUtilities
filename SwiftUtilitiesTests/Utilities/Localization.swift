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

struct Test_Localization
{
    @Test
    func stringResolvesTable() async throws
    {
        // A missing resource bundle would make NSLocalizedString echo the key
        // back, so these assertions also verify the table ships and resolves
        // under both Swift Package Manager and the Xcode framework.
        #expect( Localization.string( "GitHubUpdater.alert.error.title" )            == "Error" )
        #expect( Localization.string( "GitHubUpdater.alert.upToDate.title" )         == "You're up-to-date!" )
        #expect( Localization.string( "GitHubUpdater.window.title" )                 == "Update Available" )
        #expect( Localization.string( "GitHubUpdater.window.button.download" )       == "Download" )
        #expect( Localization.string( "GitHubUpdater.window.button.view" )           == "View on GitHub" )
        #expect( Localization.string( "GitHubUpdater.window.button.later" )          == "Later" )
        #expect( Localization.string( "Credits.window.title" )                       == "Credits" )
        #expect( Localization.string( "Credits.placeholder" )                        == "This application makes use of the following third-party projects." )
    }

    @Test
    func stringReturnsKeyForMissingEntry() async throws
    {
        #expect( Localization.string( "nonexistent.key" ) == "nonexistent.key" )
    }
}
