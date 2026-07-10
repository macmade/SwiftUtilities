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

/// Bridges a `URLSession` data task to an async stream of `Data` chunks and its
/// `URLResponse`.
///
/// A data task delivers the response body in natively sized chunks through its
/// delegate, so this avoids iterating the body one byte at a time. It backs
/// ``UpdateDownloader``'s default ``UpdateDownloader/StreamOpener``.
///
/// The streamer owns a private `URLSession` for the transfer and invalidates it
/// on completion or teardown, breaking the session's retain of its delegate.
/// Terminating the returned stream (including when the consuming task is
/// cancelled) cancels the task and tears the session down.
internal final class UpdateDownloadStreamer: NSObject, URLSessionDataDelegate, @unchecked Sendable
{
    /// Guards all mutable state, since delegate callbacks arrive on the session's
    /// delegate queue.
    private let lock = NSLock()

    /// The continuation feeding the body stream.
    private var streamContinuation: AsyncThrowingStream<Data, Error>.Continuation?

    /// The continuation awaiting the response, resumed exactly once.
    private var responseContinuation: CheckedContinuation<URLResponse, Error>?

    /// Whether the response continuation has already been resumed.
    private var responseSettled = false

    /// The private session driving the transfer.
    private var session: URLSession?

    /// The running data task.
    private var task: URLSessionDataTask?

    /// Opens a data-chunk stream for a request.
    ///
    /// Returns once the response has been received; body chunks then flow through
    /// the returned stream until the transfer completes, fails, or is cancelled.
    ///
    /// - Parameters:
    ///   - request:       The request to perform.
    ///   - configuration: The session configuration to use.
    ///
    /// - Returns: The body as a stream of `Data` chunks, and the response.
    ///
    /// - Throws: Any transport error that occurs before the response is received.
    internal static func open( request: URLRequest, configuration: URLSessionConfiguration ) async throws -> ( AsyncThrowingStream<Data, Error>, URLResponse )
    {
        try await UpdateDownloadStreamer().start( request: request, configuration: configuration )
    }

    /// Starts the transfer and awaits the response.
    ///
    /// - Parameters:
    ///   - request:       The request to perform.
    ///   - configuration: The session configuration to use.
    ///
    /// - Returns: The body stream and the response.
    ///
    /// - Throws: Any transport error that occurs before the response is received.
    private func start( request: URLRequest, configuration: URLSessionConfiguration ) async throws -> ( AsyncThrowingStream<Data, Error>, URLResponse )
    {
        // The stream is intentionally unbounded: a bounded policy drops elements
        // when full, which would silently corrupt the download. In practice disk
        // writes outpace network delivery, so the buffer stays small; true
        // backpressure would require suspending the data task, which is not
        // warranted here.
        let stream = AsyncThrowingStream<Data, Error>
        {
            continuation in

            self.lock.withLock { self.streamContinuation = continuation }

            continuation.onTermination =
            {
                [ weak self ] _ in self?.teardown()
            }
        }

        let session = URLSession( configuration: configuration, delegate: self, delegateQueue: nil )
        let task    = session.dataTask( with: request )

        self.lock.withLock
        {
            self.session = session
            self.task    = task
        }

        let response = try await withCheckedThrowingContinuation
        {
            ( continuation: CheckedContinuation<URLResponse, Error> ) in

            self.lock.withLock { self.responseContinuation = continuation }

            task.resume()
        }

        return ( stream, response )
    }

    /// Delivers the response and allows the body to be received.
    internal func urlSession( _ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping ( URLSession.ResponseDisposition ) -> Void )
    {
        self.settleResponse( .success( response ) )

        completionHandler( .allow )
    }

    /// Forwards a received body chunk to the stream.
    internal func urlSession( _ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data )
    {
        let continuation = self.lock.withLock { self.streamContinuation }

        continuation?.yield( data )
    }

    /// Finishes the stream when the transfer ends, and tears the session down.
    ///
    /// The continuation is read under the lock but finished outside it: finishing
    /// can synchronously invoke the stream's `onTermination`, which also takes the
    /// lock, and the lock is not recursive.
    internal func urlSession( _ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error? )
    {
        let continuation = self.lock.withLock { self.streamContinuation }

        if let error
        {
            self.settleResponse( .failure( error ) )

            continuation?.finish( throwing: error )
        }
        else
        {
            // No-op if the response was already delivered; guards against a hang
            // in the unexpected case where completion arrives with neither an
            // error nor a prior response.
            self.settleResponse( .failure( URLError( .badServerResponse ) ) )

            continuation?.finish()
        }

        self.invalidate()
    }

    /// Resumes the response continuation exactly once.
    ///
    /// - Parameter result: The response to deliver, or the error to throw.
    private func settleResponse( _ result: Result<URLResponse, Error> )
    {
        let continuation: CheckedContinuation<URLResponse, Error>? = self.lock.withLock
        {
            guard self.responseSettled == false
            else
            {
                return nil
            }

            self.responseSettled      = true
            let continuation          = self.responseContinuation
            self.responseContinuation = nil

            return continuation
        }

        switch result
        {
            case .success( let response ): continuation?.resume( returning: response )
            case .failure( let error ):    continuation?.resume( throwing: error )
        }
    }

    /// Cancels the transfer and tears the session down when the stream terminates.
    private func teardown()
    {
        self.lock.withLock { self.task }?.cancel()

        self.invalidate()
    }

    /// Invalidates the session, releasing its retain of this delegate. Idempotent.
    private func invalidate()
    {
        let session = self.lock.withLock
        {
            let session  = self.session
            self.session = nil

            return session
        }

        session?.finishTasksAndInvalidate()
    }
}
