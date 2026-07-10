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

/// A failure raised while downloading an update asset with ``UpdateDownloader``.
///
/// Network transport failures surface as the underlying `URLError`; these cases
/// describe failures specific to the update download itself.
public enum UpdateDownloadError: Error, Equatable, Sendable
{
    /// The server's response was not an HTTP response.
    case invalidResponse

    /// The server returned a non-success HTTP status.
    ///
    /// - Parameter statusCode: The HTTP status code received.
    case httpError( statusCode: Int )
}

extension UpdateDownloadError: LocalizedError
{
    /// A human-readable description of the error.
    public var errorDescription: String?
    {
        switch self
        {
            case .invalidResponse:

                return "The server returned an unexpected response."

            case .httpError( let statusCode ):

                return "The download failed (HTTP \( statusCode ))."
        }
    }
}
