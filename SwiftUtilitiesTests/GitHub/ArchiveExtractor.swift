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

struct Test_ArchiveExtractor
{
    // MARK: - Helpers

    private static func makeTempDirectory() throws -> URL
    {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent( "extractor-test-\( UUID().uuidString )" )

        try FileManager.default.createDirectory( at: directory, withIntermediateDirectories: true )

        return directory
    }

    /// Creates a minimal fake `.app` bundle inside a directory.
    @discardableResult
    private static func makeApp( named name: String, in directory: URL ) throws -> URL
    {
        let app       = directory.appendingPathComponent( "\( name ).app" )
        let executable = app.appendingPathComponent( "Contents/MacOS" )

        try FileManager.default.createDirectory( at: executable, withIntermediateDirectories: true )
        try Data( "#!/bin/sh\n".utf8 ).write( to: executable.appendingPathComponent( name ) )
        try Data( "<plist></plist>".utf8 ).write( to: app.appendingPathComponent( "Contents/Info.plist" ) )

        return app
    }

    /// Runs a command-line tool synchronously, failing the calling test on error.
    private static func runTool( _ path: String, _ arguments: [ String ] ) throws
    {
        let process = Process()
        process.executableURL = URL( fileURLWithPath: path )
        process.arguments     = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError  = FileHandle.nullDevice

        try process.run()
        process.waitUntilExit()

        #expect( process.terminationStatus == 0, "\( path ) \( arguments.joined( separator: " " ) ) failed (\( process.terminationStatus ))" )
    }

    // MARK: - App discovery

    @Test
    func findsSingleApplication() async throws
    {
        let directory = try Test_ArchiveExtractor.makeTempDirectory()

        defer { try? FileManager.default.removeItem( at: directory ) }

        let app   = try Test_ArchiveExtractor.makeApp( named: "MyApp", in: directory )
        let found = try ArchiveExtractor.application( in: directory )

        #expect( found.resolvingSymlinksInPath().path == app.resolvingSymlinksInPath().path )
    }

    @Test
    func findsNestedApplication() async throws
    {
        let directory = try Test_ArchiveExtractor.makeTempDirectory()
        let nested    = directory.appendingPathComponent( "sub" )

        defer { try? FileManager.default.removeItem( at: directory ) }

        try FileManager.default.createDirectory( at: nested, withIntermediateDirectories: true )

        let app   = try Test_ArchiveExtractor.makeApp( named: "MyApp", in: nested )
        let found = try ArchiveExtractor.application( in: directory )

        #expect( found.resolvingSymlinksInPath().path == app.resolvingSymlinksInPath().path )
    }

    @Test
    func throwsWhenNoApplicationFound() async throws
    {
        let directory = try Test_ArchiveExtractor.makeTempDirectory()

        defer { try? FileManager.default.removeItem( at: directory ) }

        try Data( "x".utf8 ).write( to: directory.appendingPathComponent( "readme.txt" ) )

        #expect( throws: ArchiveExtractionError.applicationNotFound )
        {
            _ = try ArchiveExtractor.application( in: directory )
        }
    }

    @Test
    func throwsWhenMultipleApplicationsFound() async throws
    {
        let directory = try Test_ArchiveExtractor.makeTempDirectory()

        defer { try? FileManager.default.removeItem( at: directory ) }

        try Test_ArchiveExtractor.makeApp( named: "One", in: directory )
        try Test_ArchiveExtractor.makeApp( named: "Two", in: directory )

        #expect( throws: ArchiveExtractionError.multipleApplicationsFound )
        {
            _ = try ArchiveExtractor.application( in: directory )
        }
    }

    @Test
    func ignoresApplicationsSymlink() async throws
    {
        let directory = try Test_ArchiveExtractor.makeTempDirectory()

        defer { try? FileManager.default.removeItem( at: directory ) }

        let app = try Test_ArchiveExtractor.makeApp( named: "MyApp", in: directory )

        // Mimic a .dmg's /Applications symlink, which must not be followed.
        try FileManager.default.createSymbolicLink( at: directory.appendingPathComponent( "Applications" ), withDestinationURL: URL( fileURLWithPath: "/Applications" ) )

        let found = try ArchiveExtractor.application( in: directory )

        #expect( found.resolvingSymlinksInPath().path == app.resolvingSymlinksInPath().path )
    }

    // MARK: - Zip extraction (real ditto)

    @Test
    func extractsApplicationFromZip() async throws
    {
        let root = try Test_ArchiveExtractor.makeTempDirectory()

        defer { try? FileManager.default.removeItem( at: root ) }

        let source = root.appendingPathComponent( "src" )

        try FileManager.default.createDirectory( at: source, withIntermediateDirectories: true )
        try Test_ArchiveExtractor.makeApp( named: "MyApp", in: source )

        let archive = root.appendingPathComponent( "MyApp.zip" )

        try Test_ArchiveExtractor.runTool( "/usr/bin/ditto", [ "-c", "-k", "--keepParent", source.appendingPathComponent( "MyApp.app" ).path, archive.path ] )

        let extractor = ArchiveExtractor()
        let app       = try await extractor.extractApplication( from: archive, format: .zip, into: root )

        #expect( app.lastPathComponent == "MyApp.app" )
        #expect( FileManager.default.fileExists( atPath: app.appendingPathComponent( "Contents/Info.plist" ).path ) )
    }

    @Test
    func throwsWhenZipHasNoApplication() async throws
    {
        let root = try Test_ArchiveExtractor.makeTempDirectory()

        defer { try? FileManager.default.removeItem( at: root ) }

        let source = root.appendingPathComponent( "src" )

        try FileManager.default.createDirectory( at: source, withIntermediateDirectories: true )
        try Data( "hello".utf8 ).write( to: source.appendingPathComponent( "notes.txt" ) )

        let archive = root.appendingPathComponent( "NoApp.zip" )

        try Test_ArchiveExtractor.runTool( "/usr/bin/ditto", [ "-c", "-k", "--keepParent", source.path, archive.path ] )

        await #expect( throws: ArchiveExtractionError.applicationNotFound )
        {
            _ = try await ArchiveExtractor().extractApplication( from: archive, format: .zip, into: root )
        }
    }

    @Test
    func throwsForCorruptZip() async throws
    {
        let root = try Test_ArchiveExtractor.makeTempDirectory()

        defer { try? FileManager.default.removeItem( at: root ) }

        let archive = root.appendingPathComponent( "corrupt.zip" )

        try Data( "this is not a zip archive".utf8 ).write( to: archive )

        await #expect( throws: ArchiveExtractionError.self )
        {
            _ = try await ArchiveExtractor().extractApplication( from: archive, format: .zip, into: root )
        }
    }

    // MARK: - Disk-image extraction (real hdiutil)

    @Test
    func extractsApplicationFromDiskImage() async throws
    {
        let root = try Test_ArchiveExtractor.makeTempDirectory()

        defer { try? FileManager.default.removeItem( at: root ) }

        let source = root.appendingPathComponent( "src" )

        try FileManager.default.createDirectory( at: source, withIntermediateDirectories: true )
        try Test_ArchiveExtractor.makeApp( named: "MyApp", in: source )

        let archive = root.appendingPathComponent( "MyApp.dmg" )

        try Test_ArchiveExtractor.runTool( "/usr/bin/hdiutil", [ "create", "-volname", "MyApp", "-srcfolder", source.path, "-format", "UDRO", "-ov", archive.path ] )

        let work = root.appendingPathComponent( "work" )

        try FileManager.default.createDirectory( at: work, withIntermediateDirectories: true )

        let extractor = ArchiveExtractor()
        let app       = try await extractor.extractApplication( from: archive, format: .dmg, into: work )

        #expect( app.lastPathComponent == "MyApp.app" )
        #expect( FileManager.default.fileExists( atPath: app.appendingPathComponent( "Contents/Info.plist" ).path ) )
    }

    @Test
    func detachesAndCleansUpWhenDiskImageHasNoApplication() async throws
    {
        let root = try Test_ArchiveExtractor.makeTempDirectory()

        defer { try? FileManager.default.removeItem( at: root ) }

        let source = root.appendingPathComponent( "src" )

        try FileManager.default.createDirectory( at: source, withIntermediateDirectories: true )
        try Data( "hello".utf8 ).write( to: source.appendingPathComponent( "notes.txt" ) )

        let archive = root.appendingPathComponent( "NoApp.dmg" )

        try Test_ArchiveExtractor.runTool( "/usr/bin/hdiutil", [ "create", "-volname", "NoApp", "-srcfolder", source.path, "-format", "UDRO", "-ov", archive.path ] )

        let work = root.appendingPathComponent( "work" )

        try FileManager.default.createDirectory( at: work, withIntermediateDirectories: true )

        await #expect( throws: ArchiveExtractionError.applicationNotFound )
        {
            _ = try await ArchiveExtractor().extractApplication( from: archive, format: .dmg, into: work )
        }

        // An empty working directory is evidence the image was detached (so the
        // container was no longer busy) and the container was removed on failure.
        let contents = try FileManager.default.contentsOfDirectory( at: work, includingPropertiesForKeys: nil )

        #expect( contents.isEmpty )
    }
}
