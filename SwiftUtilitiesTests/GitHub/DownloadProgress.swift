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

struct Test_DownloadProgress
{
    @Test
    func fractionComputedFromBytes() async throws
    {
        #expect( DownloadProgress( bytesReceived: 40, totalBytes: 100 ).fractionCompleted == 0.4 )
    }

    @Test
    func fractionClampedToOne() async throws
    {
        #expect( DownloadProgress( bytesReceived: 150, totalBytes: 100 ).fractionCompleted == 1.0 )
    }

    @Test
    func fractionNilWhenTotalUnknown() async throws
    {
        #expect( DownloadProgress( bytesReceived: 40, totalBytes: nil ).fractionCompleted == nil )
    }

    @Test
    func fractionNilWhenTotalNotPositive() async throws
    {
        #expect( DownloadProgress( bytesReceived: 0, totalBytes: 0 ).fractionCompleted == nil )
    }
}
