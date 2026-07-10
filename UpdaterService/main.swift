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

// The updater service executable runs in one of two modes.
//
// When re-invoked in relaunch mode by `ProcessRelauncher` (a detached child spawned
// after a successful install), it waits for the updated application to quit and then
// reopens it — this branch never touches XPC. Otherwise it runs as the XPC service,
// listening for install requests from the host application; `resume()` on a service
// listener does not return.
if let invocation = ProcessRelauncher.invocation( from: CommandLine.arguments )
{
    try? RelaunchWaiter().waitForExitThenOpen( processIdentifier: invocation.processIdentifier, application: invocation.application )
}
else
{
    let delegate = UpdaterServiceListenerDelegate()
    let listener = NSXPCListener.service()

    listener.delegate = delegate

    listener.resume()
}
