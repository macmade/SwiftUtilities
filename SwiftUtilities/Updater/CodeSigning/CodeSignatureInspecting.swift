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

/// The code-signing operations a ``CodeSignatureValidator`` depends on.
///
/// This is the dependency-injection seam that isolates the Security framework
/// from the validator's pure decision logic — mirroring the ``GitHubUpdater``
/// `Fetcher` seam. Production code uses ``SecurityCodeSignatureInspector``;
/// tests inject a stub so the validator can be exercised without a real signed
/// bundle, the filesystem, or the Security framework.
public protocol CodeSignatureInspecting: Sendable
{
    /// Reads the signing identity of the running application.
    ///
    /// This is the validated identity of the current process (the running
    /// application), obtained from the code the kernel launched — not from an
    /// on-disk bundle that could have been tampered with. It is the root of trust
    /// from which the expected update requirement is derived.
    ///
    /// - Returns: The running application's signing identity.
    ///
    /// - Throws: A ``CodeSignatureError`` if the running code cannot be read or
    ///   has no usable signing identifier or Team ID.
    func runningApplicationIdentity() throws -> CodeSigningIdentity

    /// Verifies that the bundle at the given URL satisfies a code requirement.
    ///
    /// - Parameters:
    ///   - url:         A file URL to the application bundle to verify.
    ///   - requirement: A Code Signing Requirement Language string the bundle
    ///                  must satisfy.
    ///
    /// - Throws: A ``CodeSignatureError`` if the code cannot be read, the
    ///   requirement is malformed, or the bundle does not satisfy it.
    func verify( bundleAt url: URL, satisfies requirement: String ) throws
}
