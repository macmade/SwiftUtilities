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

/// Downloads an update asset to a local file, reporting progress.
///
/// This is the dependency-injection seam the in-app update flow depends on for its
/// download step, so ``InAppUpdateViewModel`` can be driven with a stub instead of
/// the network. The production implementation is ``UpdateDownloader``.
public protocol UpdateDownloading: Sendable
{
    /// Downloads the asset at a URL to a local file.
    ///
    /// - Parameters:
    ///   - url:       The asset's download URL.
    ///   - directory: The base directory the download is placed under.
    ///   - progress:  Invoked with a ``DownloadProgress`` as bytes arrive.
    ///
    /// - Returns: The URL of the downloaded file.
    ///
    /// - Throws: An error if the download fails.
    func download( from url: URL, into directory: URL, progress: @Sendable ( DownloadProgress ) -> Void ) async throws -> URL
}

extension UpdateDownloader: UpdateDownloading
{}
