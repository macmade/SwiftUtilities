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

struct Test_UpdateInstallResult
{
    private struct LocalizedFailure: LocalizedError
    {
        var errorDescription: String?
        {
            "A friendly, user-facing message."
        }
    }

    private struct PlainFailure: Error
    {}

    @Test
    func successRoundTripsThroughData() throws
    {
        let decoded = try UpdateInstallResult.decoded( from: UpdateInstallResult.success.encoded() )

        #expect( decoded == .success )
    }

    @Test
    func failureRoundTripsThroughData() throws
    {
        let result  = UpdateInstallResult.failure( reason: "The update could not be installed." )
        let decoded = try UpdateInstallResult.decoded( from: result.encoded() )

        #expect( decoded == .failure( reason: "The update could not be installed." ) )
    }

    @Test
    func mapsLocalizedErrorToItsDescription()
    {
        let result = UpdateInstallResult.failure( from: LocalizedFailure() )

        #expect( result == .failure( reason: "A friendly, user-facing message." ) )
    }

    @Test
    func mapsPlainErrorToItsLocalizedDescription()
    {
        let error  = PlainFailure()
        let result = UpdateInstallResult.failure( from: error )

        #expect( result == .failure( reason: ( error as any Error ).localizedDescription ) )
    }

    @Test
    func decodingInvalidDataThrows()
    {
        #expect( throws: ( any Error ).self )
        {
            try UpdateInstallResult.decoded( from: Data( "nonsense".utf8 ) )
        }
    }
}
