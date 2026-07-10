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

struct Test_UpdateDownloader
{
    private struct StubError: Error, Equatable
    {}

    /// Collects progress reports from a download. Single-threaded test use only.
    private final class ProgressCollector: @unchecked Sendable
    {
        private( set ) var values: [ DownloadProgress ] = []

        func record( _ progress: DownloadProgress )
        {
            self.values.append( progress )
        }
    }

    /// Builds a stream that yields the given chunks, then finishes, optionally throwing.
    private static func makeStream( _ chunks: [ Data ], throwing error: ( any Error & Sendable )? = nil ) -> AsyncThrowingStream<Data, Error>
    {
        AsyncThrowingStream
        {
            continuation in

            chunks.forEach { continuation.yield( $0 ) }

            if let error
            {
                continuation.finish( throwing: error )
            }
            else
            {
                continuation.finish()
            }
        }
    }

    /// A stub stream opener returning the given chunks and an HTTP response.
    private static func stubOpener( chunks: [ Data ], status: Int = 200, contentLength: Int? = nil, streamError: ( any Error & Sendable )? = nil ) -> UpdateDownloader.StreamOpener
    {
        {
            request in

            guard let url = request.url
            else
            {
                throw StubError()
            }

            let headers = contentLength.map { [ "Content-Length": String( $0 ) ] }

            guard let response = HTTPURLResponse( url: url, statusCode: status, httpVersion: nil, headerFields: headers )
            else
            {
                throw StubError()
            }

            return ( Test_UpdateDownloader.makeStream( chunks, throwing: streamError ), response )
        }
    }

    private static func makeTempDirectory() throws -> URL
    {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent( "downloader-test-\( UUID().uuidString )" )

        try FileManager.default.createDirectory( at: directory, withIntermediateDirectories: true )

        return directory
    }

    @Test
    func successWritesFileAndReportsProgress() async throws
    {
        let chunks     = [ Data( repeating: 1, count: 40 ), Data( repeating: 2, count: 60 ) ]
        let downloader = UpdateDownloader( open: Test_UpdateDownloader.stubOpener( chunks: chunks, contentLength: 100 ) )
        let base       = try Test_UpdateDownloader.makeTempDirectory()
        let collector  = ProgressCollector()
        let asset      = try #require( URL( string: "https://example.com/App.zip" ) )

        defer
        {
            try? FileManager.default.removeItem( at: base )
        }

        let result = try await downloader.download( from: asset, into: base ) { collector.record( $0 ) }

        #expect( FileManager.default.fileExists( atPath: result.path ) )
        #expect( result.lastPathComponent == "App.zip" )

        let data = try Data( contentsOf: result )

        #expect( data.count == 100 )
        #expect( collector.values.map( \.bytesReceived )  == [ 40, 100 ] )
        #expect( collector.values.last?.totalBytes        == 100 )
    }

    @Test
    func successWithEmptyBody() async throws
    {
        let downloader = UpdateDownloader( open: Test_UpdateDownloader.stubOpener( chunks: [], contentLength: 0 ) )
        let base       = try Test_UpdateDownloader.makeTempDirectory()
        let asset      = try #require( URL( string: "https://example.com/App.zip" ) )

        defer
        {
            try? FileManager.default.removeItem( at: base )
        }

        let result = try await downloader.download( from: asset, into: base )

        #expect( FileManager.default.fileExists( atPath: result.path ) )
        #expect( try Data( contentsOf: result ).isEmpty )
    }

    @Test
    func usesFallbackFilenameWhenURLHasNoName() async throws
    {
        let downloader = UpdateDownloader( open: Test_UpdateDownloader.stubOpener( chunks: [ Data( [ 1 ] ) ], contentLength: 1 ) )
        let base       = try Test_UpdateDownloader.makeTempDirectory()
        let asset      = try #require( URL( string: "https://example.com" ) )

        defer
        {
            try? FileManager.default.removeItem( at: base )
        }

        let result = try await downloader.download( from: asset, into: base )

        #expect( result.lastPathComponent == "download" )
    }

    @Test
    func usesFallbackFilenameForBareSlashURL() async throws
    {
        let downloader = UpdateDownloader( open: Test_UpdateDownloader.stubOpener( chunks: [ Data( [ 1 ] ) ], contentLength: 1 ) )
        let base       = try Test_UpdateDownloader.makeTempDirectory()
        let asset      = try #require( URL( string: "https://example.com/" ) )

        defer
        {
            try? FileManager.default.removeItem( at: base )
        }

        let result = try await downloader.download( from: asset, into: base )

        #expect( result.lastPathComponent == "download" )
    }

    @Test
    func failsWithHTTPErrorForNon2xx() async throws
    {
        let downloader = UpdateDownloader( open: Test_UpdateDownloader.stubOpener( chunks: [], status: 404, contentLength: 0 ) )
        let base       = try Test_UpdateDownloader.makeTempDirectory()
        let asset      = try #require( URL( string: "https://example.com/App.zip" ) )

        defer
        {
            try? FileManager.default.removeItem( at: base )
        }

        await #expect( throws: UpdateDownloadError.httpError( statusCode: 404 ) )
        {
            _ = try await downloader.download( from: asset, into: base )
        }

        let contents = try FileManager.default.contentsOfDirectory( at: base, includingPropertiesForKeys: nil )

        #expect( contents.isEmpty )
    }

    @Test
    func failsWithInvalidResponseForNonHTTP() async throws
    {
        let base  = try Test_UpdateDownloader.makeTempDirectory()
        let asset = try #require( URL( string: "https://example.com/App.zip" ) )

        let opener: UpdateDownloader.StreamOpener =
        {
            request in

            guard let url = request.url
            else
            {
                throw StubError()
            }

            let response = URLResponse( url: url, mimeType: nil, expectedContentLength: -1, textEncodingName: nil )

            return ( Test_UpdateDownloader.makeStream( [] ), response )
        }

        defer
        {
            try? FileManager.default.removeItem( at: base )
        }

        await #expect( throws: UpdateDownloadError.invalidResponse )
        {
            _ = try await UpdateDownloader( open: opener ).download( from: asset, into: base )
        }

        let contents = try FileManager.default.contentsOfDirectory( at: base, includingPropertiesForKeys: nil )

        #expect( contents.isEmpty )
    }

    @Test
    func removesPartialDownloadWhenStreamFails() async throws
    {
        let chunks     = [ Data( repeating: 1, count: 40 ) ]
        let downloader = UpdateDownloader( open: Test_UpdateDownloader.stubOpener( chunks: chunks, contentLength: 100, streamError: StubError() ) )
        let base       = try Test_UpdateDownloader.makeTempDirectory()
        let asset      = try #require( URL( string: "https://example.com/App.zip" ) )

        defer
        {
            try? FileManager.default.removeItem( at: base )
        }

        await #expect( throws: StubError.self )
        {
            _ = try await downloader.download( from: asset, into: base )
        }

        let contents = try FileManager.default.contentsOfDirectory( at: base, includingPropertiesForKeys: nil )

        #expect( contents.isEmpty )
    }

    @Test
    func realTaskCancellationThrowsAndCleansUp() async throws
    {
        let base  = try Test_UpdateDownloader.makeTempDirectory()
        let asset = try #require( URL( string: "https://example.com/App.zip" ) )

        // A stream that yields one chunk then never finishes, so the download
        // suspends waiting for more data and cancellation lands during iteration
        // — the real runtime behaviour, where the stream returns nil rather than
        // throwing.
        let opener: UpdateDownloader.StreamOpener =
        {
            request in

            guard let url = request.url,
                  let response = HTTPURLResponse( url: url, statusCode: 200, httpVersion: nil, headerFields: [ "Content-Length": "1000" ] )
            else
            {
                throw StubError()
            }

            let stream = AsyncThrowingStream<Data, Error>
            {
                continuation in

                continuation.yield( Data( repeating: 1, count: 40 ) )
            }

            return ( stream, response )
        }

        let downloader = UpdateDownloader( open: opener )

        defer
        {
            try? FileManager.default.removeItem( at: base )
        }

        let task = Task
        {
            try await downloader.download( from: asset, into: base )
        }

        try await Task.sleep( for: .milliseconds( 100 ) )
        task.cancel()

        await #expect( throws: CancellationError.self )
        {
            _ = try await task.value
        }

        let contents = try FileManager.default.contentsOfDirectory( at: base, includingPropertiesForKeys: nil )

        #expect( contents.isEmpty )
    }
}
