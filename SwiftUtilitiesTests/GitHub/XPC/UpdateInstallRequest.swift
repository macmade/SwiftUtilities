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

struct Test_UpdateInstallRequest
{
    private static let identity = CodeSigningIdentity( identifier: "com.example.App", teamIdentifier: "ABCDE12345" )

    private func makeRequest() -> UpdateInstallRequest
    {
        UpdateInstallRequest(
            archive:           URL( fileURLWithPath: "/tmp/Update.zip" ),
            target:            URL( fileURLWithPath: "/Applications/App.app" ),
            identity:          Test_UpdateInstallRequest.identity,
            format:            .zip,
            processIdentifier: 4321
        )
    }

    @Test
    func roundTripsThroughData() throws
    {
        let request = self.makeRequest()
        let decoded = try UpdateInstallRequest.decoded( from: request.encoded() )

        #expect( decoded == request )
    }

    @Test
    func preservesEveryField() throws
    {
        let decoded = try UpdateInstallRequest.decoded( from: self.makeRequest().encoded() )

        #expect( decoded.archiveURL        == URL( fileURLWithPath: "/tmp/Update.zip" ) )
        #expect( decoded.targetURL         == URL( fileURLWithPath: "/Applications/App.app" ) )
        #expect( decoded.identity          == Test_UpdateInstallRequest.identity )
        #expect( decoded.format            == .zip )
        #expect( decoded.processIdentifier == 4321 )
    }

    @Test
    func exposesPathsAsFileURLs()
    {
        let request = self.makeRequest()

        #expect( request.archiveURL.isFileURL )
        #expect( request.targetURL.isFileURL )
        #expect( request.archiveURL.path == "/tmp/Update.zip" )
        #expect( request.targetURL.path  == "/Applications/App.app" )
    }

    @Test
    func decodingInvalidDataThrows()
    {
        #expect( throws: ( any Error ).self )
        {
            try UpdateInstallRequest.decoded( from: Data( "not a request".utf8 ) )
        }
    }
}
