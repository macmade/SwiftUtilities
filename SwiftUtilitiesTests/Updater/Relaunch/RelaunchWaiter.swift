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

struct Test_RelaunchWaiter
{
    private final class Liveness: @unchecked Sendable
    {
        private let runningChecks: Int

        private( set ) var checks = 0

        /// Reports the process as running for the first `runningChecks` probes, then
        /// as exited.
        init( runningChecks: Int )
        {
            self.runningChecks = runningChecks
        }

        func isRunning( _ processIdentifier: Int32 ) -> Bool
        {
            defer { self.checks += 1 }

            return self.checks < self.runningChecks
        }
    }

    private final class OpenRecorder: @unchecked Sendable
    {
        private( set ) var opened: [ URL ] = []

        func open( _ application: URL ) throws
        {
            self.opened.append( application )
        }
    }

    @Test
    func opensTheApplicationAfterItExits() throws
    {
        let liveness = Liveness( runningChecks: 3 )
        let recorder = OpenRecorder()
        let app      = URL( fileURLWithPath: "/Applications/App.app" )

        let waiter = RelaunchWaiter(
            pollInterval: 0.001,
            timeout:      5,
            isRunning:    { liveness.isRunning( $0 ) },
            open:         { try recorder.open( $0 ) }
        )

        try waiter.waitForExitThenOpen( processIdentifier: 1234, application: app )

        #expect( recorder.opened == [ app ] )
        #expect( liveness.checks == 4 )
    }

    @Test
    func timesOutAndDoesNotOpenWhenTheProcessNeverExits() throws
    {
        let recorder = OpenRecorder()

        let waiter = RelaunchWaiter(
            pollInterval: 0.001,
            timeout:      0.02,
            isRunning:    { _ in true },
            open:         { try recorder.open( $0 ) }
        )

        #expect( throws: RelaunchError.timedOutWaitingForExit )
        {
            try waiter.waitForExitThenOpen( processIdentifier: 1234, application: URL( fileURLWithPath: "/Applications/App.app" ) )
        }

        #expect( recorder.opened.isEmpty )
    }
}
