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

struct Test_UpdateArchiveFormat
{
    @Test
    func detectsZipFromFilename() async throws
    {
        #expect( UpdateArchiveFormat( filename: "App.zip" )   == .zip )
        #expect( UpdateArchiveFormat( filename: "App-1.2.zip" ) == .zip )
    }

    @Test
    func detectsDmgFromFilename() async throws
    {
        #expect( UpdateArchiveFormat( filename: "App.dmg" ) == .dmg )
    }

    @Test
    func detectionIsCaseInsensitive() async throws
    {
        #expect( UpdateArchiveFormat( filename: "App.ZIP" ) == .zip )
        #expect( UpdateArchiveFormat( filename: "App.Dmg" ) == .dmg )
    }

    @Test
    func detectsFromURL() async throws
    {
        let zip = try #require( URL( string: "https://github.com/owner/repo/releases/download/v1.0.0/App.zip" ) )
        let dmg = try #require( URL( string: "https://github.com/owner/repo/releases/download/v1.0.0/App.dmg" ) )

        #expect( UpdateArchiveFormat( url: zip ) == .zip )
        #expect( UpdateArchiveFormat( url: dmg ) == .dmg )
    }

    @Test
    func detectsFromURLIgnoringQueryAndFragment() async throws
    {
        let zip = try #require( URL( string: "https://example.com/App.zip?token=abc#frag" ) )
        let dmg = try #require( URL( string: "https://example.com/App.dmg?x=1&y=2" ) )

        #expect( UpdateArchiveFormat( url: zip ) == .zip )
        #expect( UpdateArchiveFormat( url: dmg ) == .dmg )
    }

    @Test
    func detectsFromFileExtension() async throws
    {
        #expect( UpdateArchiveFormat( fileExtension: "zip" ) == .zip )
        #expect( UpdateArchiveFormat( fileExtension: "ZIP" ) == .zip )
        #expect( UpdateArchiveFormat( fileExtension: "dmg" ) == .dmg )
        #expect( UpdateArchiveFormat( fileExtension: "pkg" ) == nil )
        #expect( UpdateArchiveFormat( fileExtension: "" )    == nil )
    }

    @Test
    func fileExtensionRoundTrips() async throws
    {
        UpdateArchiveFormat.allCases.forEach
        {
            #expect( UpdateArchiveFormat( fileExtension: $0.fileExtension ) == $0 )
        }
    }

    @Test
    func returnsNilForUnsupportedFormats() async throws
    {
        let pkg = try #require( URL( string: "https://example.com/App.pkg" ) )

        #expect( UpdateArchiveFormat( filename: "App.pkg" )    == nil )
        #expect( UpdateArchiveFormat( filename: "App.tar.gz" ) == nil )
        #expect( UpdateArchiveFormat( filename: "notes.txt" )  == nil )
        #expect( UpdateArchiveFormat( url: pkg )               == nil )
    }

    @Test
    func returnsNilWhenNoExtension() async throws
    {
        #expect( UpdateArchiveFormat( filename: "App" ) == nil )
        #expect( UpdateArchiveFormat( filename: "" )    == nil )
    }
}
