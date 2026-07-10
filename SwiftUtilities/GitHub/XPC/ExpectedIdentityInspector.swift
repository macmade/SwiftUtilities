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

/// Bridges an app-supplied expected identity into a ``CodeSignatureValidator`` for
/// the updater service.
///
/// The validator asks its inspector for the *running application's* identity and
/// checks the candidate against that identity's requirement. That is correct in the
/// app, but not in the updater service: the service's running identity is the
/// service's own, not the application's. This adapter substitutes the expected
/// identity carried in the ``UpdateInstallRequest`` for the running-identity read,
/// while delegating the actual code-signature `verify` to a real ``base``
/// inspector. The service therefore validates the extracted application against the
/// application's identity (rebuilt into a requirement by the trusted
/// ``CodeSigningIdentity/requirement`` builder), using real Security checks, and can
/// reuse ``UpdateInstallation`` unchanged.
struct ExpectedIdentityInspector: CodeSignatureInspecting
{
    /// The identity the candidate must match, supplied by the application.
    let expected: CodeSigningIdentity

    /// The inspector performing the real code-signature verification.
    let base: CodeSignatureInspecting

    /// Returns the expected identity supplied by the application.
    ///
    /// Unlike a real inspector, this does not read the running process — the running
    /// process here is the service, whose identity is not the one to validate
    /// against.
    ///
    /// - Returns: The expected application identity.
    func runningApplicationIdentity() throws -> CodeSigningIdentity
    {
        self.expected
    }

    /// Verifies a bundle against a requirement using the real ``base`` inspector.
    ///
    /// - Parameters:
    ///   - url:         A file URL to the bundle to verify.
    ///   - requirement: The requirement the bundle must satisfy.
    ///
    /// - Throws: A ``CodeSignatureError`` if the bundle does not satisfy it.
    func verify( bundleAt url: URL, satisfies requirement: String ) throws
    {
        try self.base.verify( bundleAt: url, satisfies: requirement )
    }
}
