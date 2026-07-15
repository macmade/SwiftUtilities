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

struct Test_ProcessRelauncher
{
    @Test
    func argumentsAndInvocationRoundTrip()
    {
        let invocation = ProcessRelauncher.Invocation( processIdentifier: 4242, application: URL( fileURLWithPath: "/Applications/App.app" ), sentinel: URL( fileURLWithPath: "/tmp/relaunch.sentinel" ) )
        let arguments  = ProcessRelauncher.arguments( for: invocation )
        let decoded    = ProcessRelauncher.invocation( from: [ "/path/argv0" ] + arguments )

        #expect( decoded == invocation )
    }

    @Test
    func invocationRejectsArgumentsThatAreNotRelaunchRequests()
    {
        #expect( ProcessRelauncher.invocation( from: [ "/path/argv0" ] ) == nil )
        #expect( ProcessRelauncher.invocation( from: [ "/path/argv0", ProcessRelauncher.waitArgument, "1", "/App.app" ] ) == nil )
        #expect( ProcessRelauncher.invocation( from: [ "/path/argv0", "--something-else", "1", "/App.app", "/tmp/s" ] ) == nil )
        #expect( ProcessRelauncher.invocation( from: [ "/path/argv0", ProcessRelauncher.waitArgument, "not-a-pid", "/App.app", "/tmp/s" ] ) == nil )
    }
}
