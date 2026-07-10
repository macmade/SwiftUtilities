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

/// The transport the in-app update client uses to reach the bundled service.
///
/// This is the dependency-injection seam that isolates the live `NSXPCConnection`
/// from ``XPCUpdateInstaller``'s request-building and result-mapping logic —
/// mirroring the ``GitHubUpdater`` `Fetcher` seam. Production uses
/// ``XPCUpdaterServiceConnection``; tests inject a stub so the client can be
/// exercised without a live connection or a running service.
public protocol UpdaterServiceConnecting: Sendable
{
    /// Sends an encoded install request to the service and awaits its result.
    ///
    /// - Parameters:
    ///   - request:  An ``UpdateInstallRequest`` in its encoded `Data` form.
    ///   - progress: Invoked for each progress message the service streams back, as
    ///               an encoded ``InstallProgress``. May be called on any thread.
    ///
    /// - Returns: The terminal ``UpdateInstallResult`` in its encoded `Data` form.
    ///
    /// - Throws: An error if the connection cannot be established or is dropped
    ///   before a result is delivered.
    func installUpdate( _ request: Data, progress: @escaping @Sendable ( Data ) -> Void ) async throws -> Data
}
