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

/// The app's exported object on the updater connection, receiving progress.
///
/// The connection is bidirectional: the app sets an instance of this as the
/// connection's `exportedObject`, and the service calls ``updateDidProgress(_:)``
/// on it (through the connection's client proxy) as each install phase begins. It
/// simply forwards the encoded ``InstallProgress`` to the handler supplied by
/// ``XPCUpdaterServiceConnection``.
final class XPCUpdaterClient: NSObject, UpdaterClientProtocol
{
    /// The handler that receives each encoded progress message.
    private let handler: @Sendable ( Data ) -> Void

    /// Creates a client that forwards progress to the given handler.
    ///
    /// - Parameter handler: Invoked with each encoded ``InstallProgress`` the
    ///   service reports.
    init( handler: @escaping @Sendable ( Data ) -> Void )
    {
        self.handler = handler

        super.init()
    }

    /// Forwards a progress message reported by the service.
    ///
    /// - Parameter progress: An encoded ``InstallProgress``.
    func updateDidProgress( _ progress: Data )
    {
        self.handler( progress )
    }
}
