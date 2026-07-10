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

struct Test_XPCClientVerifier
{
    @Test
    func buildsATeamScopedRequirement()
    {
        let verifier = XPCClientVerifier( teamIdentifier: "ABCDE12345" )

        #expect( verifier.requirement == "anchor apple generic and certificate leaf[subject.OU] = \"ABCDE12345\"" )
    }

    @Test
    func doesNotPinASigningIdentifier()
    {
        let verifier = XPCClientVerifier( teamIdentifier: "ABCDE12345" )

        // The client application has a different signing identifier from the service,
        // so the requirement must pin only the team, never an `identifier` clause.
        #expect( verifier.requirement.contains( "identifier" ) == false )
    }

    @Test
    func escapesTheTeamIdentifier()
    {
        let verifier = XPCClientVerifier( teamIdentifier: "A\"B\\C" )

        #expect( verifier.requirement == "anchor apple generic and certificate leaf[subject.OU] = \"A\\\"B\\\\C\"" )
    }
}
