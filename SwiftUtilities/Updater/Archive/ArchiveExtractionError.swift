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

/// A failure raised while extracting an update archive with ``ArchiveExtractor``.
public enum ArchiveExtractionError: Error, Equatable, Sendable
{
    /// The archive could not be unpacked (a tool failed, the archive is corrupt,
    /// or a disk image could not be mounted or unmounted).
    ///
    /// - Parameter reason: A human-readable description of the failure.
    case extractionFailed( reason: String )

    /// No application bundle was found in the extracted archive.
    case applicationNotFound

    /// More than one application bundle was found, so the update target is ambiguous.
    case multipleApplicationsFound
}

extension ArchiveExtractionError: LocalizedError
{
    /// A human-readable description of the error.
    public var errorDescription: String?
    {
        switch self
        {
            case .extractionFailed( let reason ):

                return reason

            case .applicationNotFound:

                return "No application was found in the downloaded archive."

            case .multipleApplicationsFound:

                return "The downloaded archive contains more than one application."
        }
    }
}
