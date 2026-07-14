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

/// Verifies that a downloaded application bundle can run on the host operating system.
///
/// This is the dependency-injection seam for the deployment-target building
/// block, so the installer that composes it can be exercised with a stub in place
/// of the real ``DeploymentTargetVerifier``.
public protocol DeploymentTargetVerifying: Sendable
{
    /// Verifies that the bundle at the given URL declares a minimum OS the host meets.
    ///
    /// A bundle that declares no minimum system version — or an unparseable one —
    /// is allowed, so the install is never blocked on missing or malformed metadata.
    ///
    /// - Parameter bundle: A file URL to the candidate application bundle.
    ///
    /// - Throws: ``DeploymentTargetError/incompatible(required:host:)`` if the
    ///   bundle requires a newer operating system than the host provides.
    func verify( bundle: URL ) throws
}
