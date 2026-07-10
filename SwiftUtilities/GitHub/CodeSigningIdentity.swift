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

/// The signing identity of an application, used to build the requirement a
/// candidate update must satisfy before it can replace the running application.
///
/// It captures the two values that identify "the same app from the same
/// developer": the signing ``identifier`` (the bundle's sealed code-signing
/// identifier) and the ``teamIdentifier`` (the Apple Developer Team ID). From
/// them, ``requirement`` builds a Code Signing Requirement Language string that
/// pins the identifier, an Apple-issued certificate chain, and the Team ID.
///
/// This is a pure value type — it performs no code-signing IO — so it lives in
/// the platform-agnostic layer and its requirement construction is fully
/// unit-testable. Reading a real bundle's identity is the job of a
/// ``CodeSignatureInspecting`` implementation. It is `Codable` so the app can
/// carry the expected identity to the updater service in an
/// ``UpdateInstallRequest``, where the service rebuilds the requirement from it.
public struct CodeSigningIdentity: Sendable, Equatable, Codable
{
    /// The code-signing identifier sealed into the signature.
    ///
    /// This is the value reported by `kSecCodeInfoIdentifier`; it remains stable
    /// across developer-approved updates, which is what makes it usable to match
    /// a new version against the running application.
    public let identifier: String

    /// The Apple Developer Team ID that signed the application.
    ///
    /// This is the value reported by `kSecCodeInfoTeamIdentifier`, which appears
    /// in the signing certificate's Subject Organizational Unit (`subject.OU`).
    public let teamIdentifier: String

    /// Creates a signing identity.
    ///
    /// - Parameters:
    ///   - identifier:     The code-signing identifier.
    ///   - teamIdentifier: The Apple Developer Team ID.
    public init( identifier: String, teamIdentifier: String )
    {
        self.identifier     = identifier
        self.teamIdentifier = teamIdentifier
    }

    /// The Code Signing Requirement Language string pinning this identity.
    ///
    /// The requirement asserts three things a legitimate update must all satisfy:
    /// the same signing `identifier`, an Apple-issued certificate chain
    /// (`anchor apple generic`, which covers Developer ID and Mac App Store
    /// distribution), and the same Team ID (`certificate leaf[subject.OU]`).
    /// Requiring the Apple anchor is essential: without it, the Team ID clause
    /// alone could be satisfied by an unrelated certificate.
    ///
    /// This deliberately does not pin the Developer-ID-specific certificate
    /// policy OIDs, so a build of the same app signed by the same team through a
    /// different Apple distribution channel still validates. Both values are
    /// quoted and escaped for the requirement language.
    public var requirement: String
    {
        "identifier \( CodeSigningIdentity.quoted( self.identifier ) ) and anchor apple generic and certificate leaf[subject.OU] = \( CodeSigningIdentity.quoted( self.teamIdentifier ) )"
    }

    /// Quotes a value as a Code Signing Requirement Language string literal.
    ///
    /// Wraps the value in double quotes, escaping backslashes and double quotes
    /// so the resulting requirement remains well-formed for any value.
    ///
    /// - Parameter value: The raw value to quote.
    ///
    /// - Returns: The quoted, escaped string literal.
    static func quoted( _ value: String ) -> String
    {
        let escaped = value.replacingOccurrences( of: "\\", with: "\\\\" ).replacingOccurrences( of: "\"", with: "\\\"" )

        return "\"\( escaped )\""
    }
}
