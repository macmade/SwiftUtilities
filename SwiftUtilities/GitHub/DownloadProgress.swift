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

/// A snapshot of an in-flight download's progress.
///
/// Reported by ``UpdateDownloader`` as bytes arrive, and consumed by the update
/// UI. It is a pure value type — it carries only the counts — so it lives in the
/// platform-agnostic layer and its ``fractionCompleted`` derivation is fully
/// unit-testable.
public struct DownloadProgress: Sendable, Equatable
{
    /// The number of bytes received so far.
    public let bytesReceived: Int64

    /// The total number of bytes expected, or `nil` when the server did not
    /// advertise a content length.
    public let totalBytes: Int64?

    /// Creates a progress snapshot.
    ///
    /// - Parameters:
    ///   - bytesReceived: The number of bytes received so far.
    ///   - totalBytes:    The total number of bytes expected, or `nil` if unknown.
    public init( bytesReceived: Int64, totalBytes: Int64? )
    {
        self.bytesReceived = bytesReceived
        self.totalBytes    = totalBytes
    }

    /// The fraction of the download completed, in the range `0...1`.
    ///
    /// Returns `nil` when the total size is unknown or not positive, signalling an
    /// indeterminate download the UI should present without a definite fraction.
    /// Otherwise the ratio is clamped to `0...1`, since a server may deliver more
    /// or fewer bytes than its advertised content length.
    public var fractionCompleted: Double?
    {
        guard let totalBytes, totalBytes > 0
        else
        {
            return nil
        }

        let fraction = Double( self.bytesReceived ) / Double( totalBytes )

        return min( 1.0, max( 0.0, fraction ) )
    }
}
