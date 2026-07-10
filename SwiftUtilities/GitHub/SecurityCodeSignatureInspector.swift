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

#if canImport( Security )

    import Foundation
    import Security

    /// A ``CodeSignatureInspecting`` implementation backed by the Security framework.
    ///
    /// Reads signing information with `SecCodeCopySigningInformation` and verifies
    /// requirements with `SecStaticCodeCheckValidityWithErrors`, using the strict
    /// flags a thorough gate should apply (all architectures, nested code, and
    /// strict bundle-structure validation).
    ///
    /// - Note: The success paths of this type require a properly signed
    ///   application bundle and cannot be exercised reliably in CI (the test
    ///   bundle is not Developer-ID signed). They are verified manually against a
    ///   signed build; the unit tests cover the pure decision logic through the
    ///   ``CodeSignatureInspecting`` seam and this type's error paths.
    public struct SecurityCodeSignatureInspector: CodeSignatureInspecting
    {
        /// Creates a Security-backed inspector.
        public init()
        {}

        /// Reads the signing identity of the running application.
        ///
        /// Obtains the current process's dynamic code object with `SecCodeCopySelf`
        /// (the code the kernel launched, identified by PID), resolves it to a
        /// static code with `SecCodeCopyStaticCode`, and reads its signing
        /// identifier and Team ID. Using the running process's own code — rather
        /// than reading the on-disk main bundle by path — keeps the requirement's
        /// root of trust tamper-resistant.
        ///
        /// - Returns: The running application's signing identity.
        ///
        /// - Throws: A ``CodeSignatureError`` if the running code cannot be read or
        ///   has no signing identifier or Team ID.
        public func runningApplicationIdentity() throws -> CodeSigningIdentity
        {
            var code: SecCode?
            let codeStatus = SecCodeCopySelf( [], &code )

            guard codeStatus == errSecSuccess, let code
            else
            {
                throw CodeSignatureError.staticCodeUnavailable( reason: SecurityCodeSignatureInspector.message( for: codeStatus ) )
            }

            // Validate the running code before trusting its signing information.
            // The Security framework only guarantees complete, reliable signing
            // information after a successful validity check; without this, a
            // tampered self could yield partial or misleading identity data.
            let validityStatus = SecCodeCheckValidity( code, [], nil )

            guard validityStatus == errSecSuccess
            else
            {
                throw CodeSignatureError.validationFailed( reason: "The running application's own signature is invalid: \( SecurityCodeSignatureInspector.message( for: validityStatus ) )" )
            }

            var staticCode: SecStaticCode?
            let staticStatus = SecCodeCopyStaticCode( code, [], &staticCode )

            guard staticStatus == errSecSuccess, let staticCode
            else
            {
                throw CodeSignatureError.staticCodeUnavailable( reason: SecurityCodeSignatureInspector.message( for: staticStatus ) )
            }

            return try self.signingIdentity( of: staticCode )
        }

        /// Reads the signing identity of a static code object.
        ///
        /// - Parameter staticCode: The static code to read.
        ///
        /// - Returns: The code's signing identity.
        ///
        /// - Throws: ``CodeSignatureError/signingIdentityUnavailable(reason:)`` if
        ///   the signing information, identifier, or Team ID is missing.
        private func signingIdentity( of staticCode: SecStaticCode ) throws -> CodeSigningIdentity
        {
            var information: CFDictionary?
            let status = SecCodeCopySigningInformation( staticCode, SecCSFlags( rawValue: UInt32( kSecCSSigningInformation ) ), &information )

            guard status == errSecSuccess, let info = information as? [ String: Any ]
            else
            {
                throw CodeSignatureError.signingIdentityUnavailable( reason: SecurityCodeSignatureInspector.message( for: status ) )
            }

            guard let identifier = info[ kSecCodeInfoIdentifier as String ] as? String
            else
            {
                throw CodeSignatureError.signingIdentityUnavailable( reason: "The application has no code-signing identifier." )
            }

            guard let team = info[ kSecCodeInfoTeamIdentifier as String ] as? String
            else
            {
                throw CodeSignatureError.signingIdentityUnavailable( reason: "The application has no Team Identifier." )
            }

            return CodeSigningIdentity( identifier: identifier, teamIdentifier: team )
        }

        /// Verifies that the bundle at the given URL satisfies a code requirement.
        ///
        /// - Parameters:
        ///   - url:         A file URL to the application bundle to verify.
        ///   - requirement: A Code Signing Requirement Language string the bundle
        ///                  must satisfy.
        ///
        /// - Throws: A ``CodeSignatureError`` if the code cannot be read, the
        ///   requirement is malformed, or the bundle does not satisfy it.
        public func verify( bundleAt url: URL, satisfies requirement: String ) throws
        {
            let staticCode = try self.makeStaticCode( at: url )

            var codeRequirement: SecRequirement?
            let requirementStatus = SecRequirementCreateWithString( requirement as CFString, [], &codeRequirement )

            guard requirementStatus == errSecSuccess, let codeRequirement
            else
            {
                throw CodeSignatureError.requirementInvalid( reason: SecurityCodeSignatureInspector.message( for: requirementStatus ) )
            }

            // Validate strictly: every architecture, all nested code, and the
            // stricter bundle-structure rules. Certificate expiration and
            // revocation are deliberately not enforced (no kSecCSConsiderExpiration
            // / kSecCSEnforceRevocationChecks), matching Gatekeeper's default so a
            // legitimately signed, timestamped build is not rejected once its
            // signing certificate expires; the Apple anchor and Team ID still gate
            // the identity.
            let flags = SecCSFlags( rawValue: UInt32( kSecCSCheckAllArchitectures ) | UInt32( kSecCSCheckNestedCode ) | UInt32( kSecCSStrictValidate ) )

            var validationError: Unmanaged<CFError>?
            let status = SecStaticCodeCheckValidityWithErrors( staticCode, flags, codeRequirement, &validationError )

            guard status == errSecSuccess
            else
            {
                let reason = validationError?.takeRetainedValue().localizedDescription ?? SecurityCodeSignatureInspector.message( for: status )

                throw CodeSignatureError.validationFailed( reason: reason )
            }
        }

        /// Creates a static code object for the bundle at the given URL.
        ///
        /// - Parameter url: A file URL to the application bundle.
        ///
        /// - Returns: The static code object representing the bundle.
        ///
        /// - Throws: ``CodeSignatureError/staticCodeUnavailable(reason:)`` if the
        ///   object cannot be created (for example, the path does not exist).
        private func makeStaticCode( at url: URL ) throws -> SecStaticCode
        {
            var staticCode: SecStaticCode?
            let status = SecStaticCodeCreateWithPath( url as CFURL, [], &staticCode )

            guard status == errSecSuccess, let staticCode
            else
            {
                throw CodeSignatureError.staticCodeUnavailable( reason: SecurityCodeSignatureInspector.message( for: status ) )
            }

            return staticCode
        }

        /// Returns a human-readable message for a Security framework status code.
        ///
        /// - Parameter status: The `OSStatus` to describe.
        ///
        /// - Returns: The Security framework's description, or a fallback naming
        ///   the raw status when none is available.
        private static func message( for status: OSStatus ) -> String
        {
            ( SecCopyErrorMessageString( status, nil ) as String? ) ?? "OSStatus \( status )"
        }
    }

#endif
