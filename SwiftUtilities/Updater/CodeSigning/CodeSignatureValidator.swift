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

/// The security gate for in-app updates: verifies that a downloaded application
/// is signed by the same developer as the running application before it is
/// allowed to replace it on disk.
///
/// It derives the expected requirement from the running application's own
/// signing identity (its ``CodeSigningIdentity/requirement``) and checks that
/// the candidate satisfies it. Because the requirement pins the signing
/// identifier, an Apple-issued certificate chain, and the Team ID, a candidate
/// that is unsigned, signed by a different team, or a different application is
/// rejected. No on-disk replacement should ever happen without this succeeding.
///
/// The Security framework work is delegated to an injected
/// ``CodeSignatureInspecting``, so the validator's decision logic is
/// unit-testable with a stub. On platforms where the Security framework is
/// available, ``init()`` wires the real ``SecurityCodeSignatureInspector``.
public struct CodeSignatureValidator: Sendable
{
    /// The seam performing the actual code-signing reads and checks.
    private let inspector: CodeSignatureInspecting

    /// Creates a validator using the given inspector.
    ///
    /// This is the dependency-injection entry point used by tests and by callers
    /// that want to supply a custom code-signing implementation.
    ///
    /// - Parameter inspector: The code-signing operations to use.
    public init( inspector: CodeSignatureInspecting )
    {
        self.inspector = inspector
    }

    /// Verifies that a candidate application matches the running application's identity.
    ///
    /// Reads the running application's validated signing identity, builds the
    /// requirement it implies, and checks that the candidate satisfies it. The
    /// candidate is never accepted unless every step succeeds; any failure throws
    /// and the caller must refuse to install the update.
    ///
    /// The requirement is derived from the running process's own identity (not
    /// from an on-disk bundle), so the root of trust is the code the kernel
    /// launched.
    ///
    /// - Parameter candidateURL: A file URL to the downloaded application bundle
    ///   to validate.
    ///
    /// - Throws: A ``CodeSignatureError`` if the running application's identity
    ///   cannot be read, or if the candidate does not satisfy the derived
    ///   requirement.
    public func validate( candidateAt candidateURL: URL ) throws
    {
        let identity = try self.inspector.runningApplicationIdentity()

        try self.inspector.verify( bundleAt: candidateURL, satisfies: identity.requirement )
    }
}

#if canImport( Security )

    public extension CodeSignatureValidator
    {
        /// Creates a validator backed by the Security framework.
        ///
        /// Uses ``SecurityCodeSignatureInspector`` to read identities and check
        /// requirements against real code signatures.
        init()
        {
            self.init( inspector: SecurityCodeSignatureInspector() )
        }
    }

#endif
