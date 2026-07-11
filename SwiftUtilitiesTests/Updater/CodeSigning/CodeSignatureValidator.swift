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

struct Test_CodeSignatureValidator
{
    private struct StubError: Error, Equatable
    {}

    /// A recording stub of the Security seam. Single-threaded test use only.
    private final class StubInspector: CodeSignatureInspecting, @unchecked Sendable
    {
        let identity:      CodeSigningIdentity?
        let identityError: Error?
        let verifyError:   Error?

        private( set ) var identityRequested: Bool = false
        private( set ) var verifiedURL:       URL?
        private( set ) var verifiedRequirement: String?

        init( identity: CodeSigningIdentity? = nil, identityError: Error? = nil, verifyError: Error? = nil )
        {
            self.identity      = identity
            self.identityError = identityError
            self.verifyError   = verifyError
        }

        func runningApplicationIdentity() throws -> CodeSigningIdentity
        {
            self.identityRequested = true

            if let identityError = self.identityError
            {
                throw identityError
            }

            guard let identity = self.identity
            else
            {
                throw StubError()
            }

            return identity
        }

        func verify( bundleAt url: URL, satisfies requirement: String ) throws
        {
            self.verifiedURL         = url
            self.verifiedRequirement = requirement

            if let verifyError = self.verifyError
            {
                throw verifyError
            }
        }
    }

    @Test
    func validateDerivesRequirementFromRunningAppAndVerifiesCandidate() async throws
    {
        let identity  = CodeSigningIdentity( identifier: "com.example.App", teamIdentifier: "ABCDE12345" )
        let inspector = StubInspector( identity: identity )
        let validator = CodeSignatureValidator( inspector: inspector )
        let candidate = try #require( URL( string: "file:///tmp/New.app" ) )

        try validator.validate( candidateAt: candidate )

        #expect( inspector.identityRequested )
        #expect( inspector.verifiedURL         == candidate )
        #expect( inspector.verifiedRequirement == identity.requirement )
    }

    @Test
    func validateThrowsWhenVerificationFails() async throws
    {
        let identity  = CodeSigningIdentity( identifier: "com.example.App", teamIdentifier: "ABCDE12345" )
        let inspector = StubInspector( identity: identity, verifyError: StubError() )
        let validator = CodeSignatureValidator( inspector: inspector )
        let candidate = try #require( URL( string: "file:///tmp/New.app" ) )

        #expect( throws: StubError.self )
        {
            try validator.validate( candidateAt: candidate )
        }
    }

    @Test
    func validateRefusesWithoutVerifyingWhenIdentityUnavailable() async throws
    {
        let inspector = StubInspector( identityError: StubError() )
        let validator = CodeSignatureValidator( inspector: inspector )
        let candidate = try #require( URL( string: "file:///tmp/New.app" ) )

        #expect( throws: StubError.self )
        {
            try validator.validate( candidateAt: candidate )
        }

        #expect( inspector.verifiedURL == nil )
    }
}
