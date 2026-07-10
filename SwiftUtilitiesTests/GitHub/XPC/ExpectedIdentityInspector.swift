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

struct Test_ExpectedIdentityInspector
{
    private final class RecordingInspector: CodeSignatureInspecting, @unchecked Sendable
    {
        private( set ) var verifiedURL:         URL?
        private( set ) var verifiedRequirement: String?

        func runningApplicationIdentity() throws -> CodeSigningIdentity
        {
            CodeSigningIdentity( identifier: "com.example.Service", teamIdentifier: "ZZZZZ00000" )
        }

        func verify( bundleAt url: URL, satisfies requirement: String ) throws
        {
            self.verifiedURL         = url
            self.verifiedRequirement = requirement
        }
    }

    @Test
    func returnsTheExpectedIdentityNotTheRunningOne() throws
    {
        let expected  = CodeSigningIdentity( identifier: "com.example.App", teamIdentifier: "ABCDE12345" )
        let inspector = ExpectedIdentityInspector( expected: expected, base: RecordingInspector() )

        #expect( try inspector.runningApplicationIdentity() == expected )
    }

    @Test
    func delegatesVerificationToTheBaseInspector() throws
    {
        let expected  = CodeSigningIdentity( identifier: "com.example.App", teamIdentifier: "ABCDE12345" )
        let base      = RecordingInspector()
        let inspector = ExpectedIdentityInspector( expected: expected, base: base )
        let bundle    = URL( fileURLWithPath: "/tmp/New.app" )

        try inspector.verify( bundleAt: bundle, satisfies: expected.requirement )

        #expect( base.verifiedURL         == bundle )
        #expect( base.verifiedRequirement == expected.requirement )
    }
}
