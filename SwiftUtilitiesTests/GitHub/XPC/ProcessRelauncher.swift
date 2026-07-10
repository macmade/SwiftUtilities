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
    private final class SpawnRecorder: @unchecked Sendable
    {
        private( set ) var executable: URL?
        private( set ) var arguments:  [ String ]?

        func spawn( _ executable: URL, _ arguments: [ String ] ) throws
        {
            self.executable = executable
            self.arguments  = arguments
        }
    }

    @Test
    func relaunchSpawnsTheExecutableInRelaunchMode() throws
    {
        let recorder   = SpawnRecorder()
        let executable = URL( fileURLWithPath: "/path/to/Updater.xpc/Contents/MacOS/Updater" )
        let relauncher = ProcessRelauncher( processIdentifier: 777, executableURL: executable )
        {
            try recorder.spawn( $0, $1 )
        }

        try relauncher.relaunch( URL( fileURLWithPath: "/Applications/App.app" ) )

        #expect( recorder.executable == executable )
        #expect( recorder.arguments  == [ ProcessRelauncher.waitArgument, "777", "/Applications/App.app" ] )
    }

    @Test
    func argumentsAndInvocationRoundTrip()
    {
        let invocation = ProcessRelauncher.Invocation( processIdentifier: 4242, application: URL( fileURLWithPath: "/Applications/App.app" ) )
        let arguments  = ProcessRelauncher.arguments( for: invocation )
        let decoded    = ProcessRelauncher.invocation( from: [ "/path/argv0" ] + arguments )

        #expect( decoded == invocation )
    }

    @Test
    func invocationRejectsArgumentsThatAreNotRelaunchRequests()
    {
        #expect( ProcessRelauncher.invocation( from: [ "/path/argv0" ] ) == nil )
        #expect( ProcessRelauncher.invocation( from: [ "/path/argv0", "--something-else", "1", "/App.app" ] ) == nil )
        #expect( ProcessRelauncher.invocation( from: [ "/path/argv0", ProcessRelauncher.waitArgument, "not-a-pid", "/App.app" ] ) == nil )
    }
}
