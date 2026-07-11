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

/// The interface the framework-bundled updater service vends to the app.
///
/// This is the service side of an `NSXPCConnection`: the app sets it as the
/// connection's `remoteObjectInterface` (via `NSXPCInterface(with:)`) and calls it
/// through a remote-object proxy. `NSXPCConnection` requires the interface to be an
/// `@objc` protocol, and each remote call returns its result through a reply block
/// rather than a return value.
///
/// The messages cross the wire as `Data`, the ``XPCMessage`` encoding of the typed
/// request and result. `Data` is one of the types `NSXPCConnection` permits by
/// default, so no argument classes have to be whitelisted on the interface.
///
/// Progress is *not* reported through this interface. The connection is
/// bidirectional: the app exports an ``UpdaterClientProtocol`` object, and the
/// service streams progress to it (obtained via the incoming connection's
/// remote-object proxy) while the install runs. The reply block below delivers only
/// the terminal outcome; a dropped connection is surfaced to the app through the
/// proxy's error handler, not through this reply.
@objc
public protocol UpdaterServiceProtocol
{
    /// Installs a downloaded update, off the sandbox, inside the service.
    ///
    /// - Parameters:
    ///   - request: An ``UpdateInstallRequest`` in its ``XPCMessage/encoded()``
    ///              `Data` form.
    ///   - reply:   Called exactly once with an ``UpdateInstallResult`` in its
    ///              encoded `Data` form. It may be invoked on an arbitrary queue.
    func installUpdate( _ request: Data, withReply reply: @escaping @Sendable ( Data ) -> Void )
}
