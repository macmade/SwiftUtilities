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

#if canImport( Security )
import Security
#endif

/// Verifies that a process connecting to the updater service is a trusted client.
///
/// The updater service performs privileged file operations, so it must only serve
/// the application it belongs to — never an arbitrary process that discovers the
/// endpoint. The legitimate client is the host application, which a developer signs
/// with the **same Team ID** as the embedded service (they re-sign the whole bundle
/// with their identity). This verifier therefore requires the peer to be signed by
/// the same team, under an Apple-issued certificate chain.
///
/// The peer is identified by its **audit token**, not its PID: a PID can be reused
/// by a different process between the connection and the check, which is a
/// well-known XPC privilege-escalation vector. The audit token names the exact
/// peer process.
///
/// The requirement construction is pure and unit-testable; the actual code-signature
/// check (``isValidClient(auditToken:)``) uses the Security framework and can only
/// be exercised at runtime against a real signed peer.
///
/// > Important: Because dynamic code-signature validation is lazy (pages are checked
/// > as they are swapped in), an attacker could otherwise load unsigned code after
/// > the check. This is mitigated by the legitimate client shipping with the
/// > **hardened runtime** (the `CS_HARD` / `CS_KILL` enforcement flags), which the
/// > updater's distribution requires.
public struct XPCClientVerifier: Sendable
{
    /// The Code Signing Requirement Language string the peer must satisfy.
    ///
    /// It pins an Apple-issued certificate chain and the expected Team ID, but not a
    /// specific signing identifier — the client application has a different
    /// identifier from the service, only the same team.
    public let requirement: String

    /// Creates a verifier requiring the peer to be signed by the given team.
    ///
    /// - Parameter teamIdentifier: The Apple Developer Team ID the peer must match
    ///   (typically the updater service's own Team ID).
    public init( teamIdentifier: String )
    {
        self.requirement = "anchor apple generic and certificate leaf[subject.OU] = \( CodeSigningIdentity.quoted( teamIdentifier ) )"
    }

    #if canImport( Security )

    /// Reports whether the peer named by an audit token satisfies the requirement.
    ///
    /// Resolves the audit token to the peer's code object with
    /// `SecCodeCopyGuestWithAttributes` (using `kSecGuestAttributeAudit`), then
    /// checks it against the requirement with `SecCodeCheckValidity`. Any failure —
    /// an unresolvable token, a malformed requirement, or a peer that does not
    /// satisfy it — returns `false`; the service must then refuse the connection.
    ///
    /// - Parameter auditToken: The connecting peer's audit token.
    ///
    /// - Returns: `true` only if the peer is validly signed and satisfies the
    ///   requirement.
    public func isValidClient( auditToken: audit_token_t ) -> Bool
    {
        var token     = auditToken
        let tokenData = Data( bytes: &token, count: MemoryLayout< audit_token_t >.size )
        let attributes = [ kSecGuestAttributeAudit: tokenData ] as CFDictionary

        var code: SecCode?

        guard SecCodeCopyGuestWithAttributes( nil, attributes, [], &code ) == errSecSuccess, let code
        else
        {
            return false
        }

        var requirement: SecRequirement?

        guard SecRequirementCreateWithString( self.requirement as CFString, [], &requirement ) == errSecSuccess, let requirement
        else
        {
            return false
        }

        return SecCodeCheckValidity( code, [], requirement ) == errSecSuccess
    }

    #endif
}
