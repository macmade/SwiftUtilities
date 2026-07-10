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

struct Test_AppReplacer
{
    private static func makeTempDirectory() throws -> URL
    {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent( "replacer-test-\( UUID().uuidString )" )

        try FileManager.default.createDirectory( at: directory, withIntermediateDirectories: true )

        return directory
    }

    /// Creates a fake `.app` bundle with a single marker file.
    private static func makeApp( named name: String, marker: String, in directory: URL ) throws -> URL
    {
        let app      = directory.appendingPathComponent( "\( name ).app" )
        let contents = app.appendingPathComponent( "Contents" )

        try FileManager.default.createDirectory( at: contents, withIntermediateDirectories: true )
        try Data( marker.utf8 ).write( to: contents.appendingPathComponent( "marker.txt" ) )

        return app
    }

    @Test
    func replacesApplicationBundleAndConsumesReplacement() async throws
    {
        let root = try Test_AppReplacer.makeTempDirectory()

        defer { try? FileManager.default.removeItem( at: root ) }

        let target      = try Test_AppReplacer.makeApp( named: "Target", marker: "old", in: root )
        let replacement = try Test_AppReplacer.makeApp( named: "Replacement", marker: "new", in: root )

        let installed = try AppReplacer().replaceApplication( at: target, with: replacement )
        let marker    = try String( contentsOf: installed.appendingPathComponent( "Contents/marker.txt" ), encoding: .utf8 )

        #expect( marker == "new" )
        #expect( FileManager.default.fileExists( atPath: installed.path ) )
        #expect( FileManager.default.fileExists( atPath: replacement.path ) == false )
    }

    @Test
    func throwsWhenReplacementDoesNotExist() async throws
    {
        let root = try Test_AppReplacer.makeTempDirectory()

        defer { try? FileManager.default.removeItem( at: root ) }

        let target      = try Test_AppReplacer.makeApp( named: "Target", marker: "old", in: root )
        let replacement = root.appendingPathComponent( "Missing.app" )

        #expect( throws: ( any Error ).self )
        {
            _ = try AppReplacer().replaceApplication( at: target, with: replacement )
        }
    }
}
