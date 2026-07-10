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

/// Downloads an update asset to a local file, reporting progress and cleaning
/// up on failure.
///
/// The download is written to disk chunk by chunk as it arrives, rather than
/// buffering the whole asset in memory, and reports fractional
/// ``DownloadProgress`` as bytes arrive. The asset is written
/// into a unique temporary directory under a caller-chosen base, keeping its
/// original filename so the archive format can be detected downstream. On any
/// failure — a non-success HTTP status, a transport error, or cancellation — the
/// partial download is removed, so the caller only ever receives a complete file.
///
/// The network transport is behind an injectable ``StreamOpener`` seam, mirroring
/// the ``GitHubUpdater`` `Fetcher` seam, so the progress, file-handling, and
/// cancellation logic is unit-testable without the network. Cancellation is
/// cooperative: cancelling the task running ``download(from:into:progress:)``
/// stops the transfer and cleans up.
public struct UpdateDownloader: Sendable
{
    /// Opens a stream of the response body for a request.
    ///
    /// Returns the body as a stream of `Data` chunks together with the
    /// `URLResponse`, from which the expected content length and HTTP status are
    /// read. This is the dependency-injection seam: production uses a
    /// `URLSession`-backed opener, tests inject a stub.
    public typealias StreamOpener = @Sendable ( URLRequest ) async throws -> ( AsyncThrowingStream<Data, Error>, URLResponse )

    /// The seam opening the response-body stream for a request.
    private let open: StreamOpener

    /// Creates a downloader using the given stream opener.
    ///
    /// This is the dependency-injection entry point used by tests.
    ///
    /// - Parameter open: The seam opening the response-body stream.
    public init( open: @escaping StreamOpener )
    {
        self.open = open
    }

    /// Creates a downloader backed by a `URLSession`.
    ///
    /// - Parameter configuration: The session configuration used to fetch the
    ///   asset. Defaults to `URLSessionConfiguration.default`.
    public init( configuration: URLSessionConfiguration = .default )
    {
        self.init( open: UpdateDownloader.streamOpener( configuration: configuration ) )
    }

    /// Downloads the asset at a URL to a local file.
    ///
    /// The asset is written into a fresh, uniquely named subdirectory of
    /// `directory`, keeping its original filename. On success the URL of the
    /// written file is returned and the caller owns it; on any failure the
    /// subdirectory is removed before the error is rethrown.
    ///
    /// - Parameters:
    ///   - url:       The asset's download URL.
    ///   - directory: The base directory the download is placed under. Defaults to
    ///                the system temporary directory.
    ///   - progress:  Invoked with a ``DownloadProgress`` each time a chunk is
    ///                written. Defaults to ignoring progress.
    ///
    /// - Returns: The URL of the downloaded file.
    ///
    /// - Throws: ``UpdateDownloadError`` for a non-HTTP or non-success response, a
    ///   `URLError` for transport failures, `CancellationError` if cancelled, or a
    ///   filesystem error if the file cannot be written.
    public func download( from url: URL, into directory: URL = FileManager.default.temporaryDirectory, progress: @Sendable ( DownloadProgress ) -> Void = { _ in } ) async throws -> URL
    {
        let ( stream, response ) = try await self.open( URLRequest( url: url ) )

        guard let http = response as? HTTPURLResponse
        else
        {
            throw UpdateDownloadError.invalidResponse
        }

        guard ( 200 ..< 300 ).contains( http.statusCode )
        else
        {
            throw UpdateDownloadError.httpError( statusCode: http.statusCode )
        }

        let totalBytes  = response.expectedContentLength >= 0 ? response.expectedContentLength : nil
        let container   = directory.appendingPathComponent( UUID().uuidString, isDirectory: true )
        let destination = container.appendingPathComponent( UpdateDownloader.filename( for: url ) )

        try FileManager.default.createDirectory( at: container, withIntermediateDirectories: true )

        var succeeded = false

        defer
        {
            if succeeded == false
            {
                try? FileManager.default.removeItem( at: container )
            }
        }

        FileManager.default.createFile( atPath: destination.path, contents: nil )

        let handle = try FileHandle( forWritingTo: destination )

        defer
        {
            try? handle.close()
        }

        var bytesReceived: Int64 = 0

        for try await chunk in stream
        {
            try Task.checkCancellation()
            try handle.write( contentsOf: chunk )

            bytesReceived += Int64( chunk.count )

            progress( DownloadProgress( bytesReceived: bytesReceived, totalBytes: totalBytes ) )
        }

        // A cancelled task ends the stream by returning `nil` rather than
        // throwing, so the loop exits normally. Check again here so a cancelled
        // download fails (and is cleaned up) instead of returning a partial file.
        try Task.checkCancellation()

        succeeded = true

        return destination
    }

    /// The filename to store an asset under, derived from its URL.
    ///
    /// - Parameter url: The asset's download URL.
    ///
    /// - Returns: The URL's last path component, or `"download"` when it has no
    ///   usable filename (empty, or a bare `/`).
    private static func filename( for url: URL ) -> String
    {
        let name = url.lastPathComponent

        return ( name.isEmpty || name == "/" ) ? "download" : name
    }

    /// Builds a `URLSession`-backed stream opener.
    ///
    /// The opener drives a data task through ``UpdateDownloadStreamer``, which
    /// delivers the body in natively sized `Data` chunks.
    ///
    /// - Parameter configuration: The session configuration to use.
    ///
    /// - Returns: A ``StreamOpener`` streaming the response body in chunks.
    private static func streamOpener( configuration: URLSessionConfiguration ) -> StreamOpener
    {
        {
            request in

            try await UpdateDownloadStreamer.open( request: request, configuration: configuration )
        }
    }
}
