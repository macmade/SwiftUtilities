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

/// The interface the app vends to the updater service to receive progress.
///
/// This is the client side of the bidirectional `NSXPCConnection`: the app sets it
/// as the connection's `exportedInterface` and provides a conforming
/// `exportedObject`; the service reaches it through the incoming connection's
/// remote-object proxy and calls it as each install phase begins. Like the service
/// interface, `NSXPCConnection` requires it to be an `@objc` protocol.
///
/// It carries progress only. The terminal success or failure is delivered through
/// the reply block of ``UpdaterServiceProtocol/installUpdate(_:withReply:)``, not
/// here. The call is one-way (no reply block), so the service never blocks on the
/// app to report progress.
@objc
public protocol UpdaterClientProtocol
{
    /// Reports that the installation has entered a new phase.
    ///
    /// - Parameter progress: An ``InstallProgress`` in its ``XPCMessage/encoded()``
    ///                       `Data` form. It may be invoked on an arbitrary queue.
    func updateDidProgress( _ progress: Data )
}
