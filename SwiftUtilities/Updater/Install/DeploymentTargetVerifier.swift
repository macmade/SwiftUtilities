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

/// Verifies a bundle's `LSMinimumSystemVersion` against the host operating system.
///
/// Reads `LSMinimumSystemVersion` from the candidate bundle's `Contents/Info.plist`,
/// parses it into an `OperatingSystemVersion`, and compares it against the host,
/// throwing ``DeploymentTargetError/incompatible(required:host:)`` when the host is
/// too old. The comparison uses the same component-wise ordering (major, then minor,
/// then patch) as `ProcessInfo.isOperatingSystemAtLeast(_:)`, but against an
/// injectable host version — that Apple API only ever tests the running process's own
/// OS, so it cannot be pointed at a fixed version in a unit test.
///
/// When the key is absent or unparseable the verifier is lenient and allows the
/// install, so a missing or malformed value never blocks an update.
public struct DeploymentTargetVerifier: DeploymentTargetVerifying
{
    /// The host operating-system version a candidate bundle is checked against.
    private let host: OperatingSystemVersion

    /// Creates a verifier for the given host operating-system version.
    ///
    /// - Parameter host: The host's operating-system version. Defaults to the running
    ///   system's version (`ProcessInfo.processInfo.operatingSystemVersion`).
    public init( host: OperatingSystemVersion = ProcessInfo.processInfo.operatingSystemVersion )
    {
        self.host = host
    }

    /// Verifies that the bundle at the given URL can run on the host.
    ///
    /// - Parameter bundle: A file URL to the candidate application bundle.
    ///
    /// - Throws: ``DeploymentTargetError/incompatible(required:host:)`` if the
    ///   bundle's `LSMinimumSystemVersion` is newer than the host version.
    public func verify( bundle: URL ) throws
    {
        guard let string   = DeploymentTargetVerifier.minimumSystemVersion( ofBundleAt: bundle ),
              let required  = DeploymentTargetVerifier.operatingSystemVersion( from: string )
        else
        {
            return
        }

        guard DeploymentTargetVerifier.version( self.host, isAtLeast: required )
        else
        {
            throw DeploymentTargetError.incompatible(
                required: DeploymentTargetVerifier.describe( required ),
                host:     DeploymentTargetVerifier.describe( self.host )
            )
        }
    }

    /// Reads the `LSMinimumSystemVersion` string from a bundle's `Info.plist`.
    ///
    /// - Parameter bundle: A file URL to the candidate application bundle.
    ///
    /// - Returns: The raw version string, or `nil` if the plist cannot be read or the
    ///   key is absent.
    private static func minimumSystemVersion( ofBundleAt bundle: URL ) -> String?
    {
        let plist = bundle.appendingPathComponent( "Contents/Info.plist" )

        guard let data       = try? Data( contentsOf: plist ),
              let dictionary = try? PropertyListSerialization.propertyList( from: data, options: [], format: nil ) as? [ String: Any ]
        else
        {
            return nil
        }

        return dictionary[ "LSMinimumSystemVersion" ] as? String
    }

    /// Parses a dotted version string into an `OperatingSystemVersion`.
    ///
    /// Absent minor or patch components default to `0`; a string that is empty, has
    /// no components, or has any non-numeric component is treated as unparseable.
    ///
    /// - Parameter string: The dotted version string (e.g. `"13.0"` or `"13.4.1"`).
    ///
    /// - Returns: The parsed version, or `nil` if it cannot be parsed.
    private static func operatingSystemVersion( from string: String ) -> OperatingSystemVersion?
    {
        let trimmed    = string.trimmingCharacters( in: .whitespacesAndNewlines )
        let components = trimmed.split( separator: ".", omittingEmptySubsequences: false ).map { Int( $0 ) }

        guard components.isEmpty == false, components.allSatisfy( { $0 != nil } )
        else
        {
            return nil
        }

        let numbers = components.compactMap { $0 }
        let major   = numbers[ 0 ]
        let minor   = numbers.count > 1 ? numbers[ 1 ] : 0
        let patch   = numbers.count > 2 ? numbers[ 2 ] : 0

        return OperatingSystemVersion( majorVersion: major, minorVersion: minor, patchVersion: patch )
    }

    /// Returns whether one operating-system version is at least another.
    ///
    /// Compares the major, minor, and patch components in order, matching the
    /// semantics of `ProcessInfo.isOperatingSystemAtLeast(_:)`.
    ///
    /// - Parameters:
    ///   - host:     The version to test.
    ///   - required: The minimum version to satisfy.
    ///
    /// - Returns: `true` if `host` is greater than or equal to `required`.
    private static func version( _ host: OperatingSystemVersion, isAtLeast required: OperatingSystemVersion ) -> Bool
    {
        ( host.majorVersion, host.minorVersion, host.patchVersion ) >= ( required.majorVersion, required.minorVersion, required.patchVersion )
    }

    /// Formats an operating-system version as a human-readable string.
    ///
    /// Renders `major.minor`, appending `.patch` only when the patch component is
    /// non-zero, so the common two-component form stays uncluttered.
    ///
    /// - Parameter version: The version to describe.
    ///
    /// - Returns: The formatted version string.
    private static func describe( _ version: OperatingSystemVersion ) -> String
    {
        if version.patchVersion > 0
        {
            return "\( version.majorVersion ).\( version.minorVersion ).\( version.patchVersion )"
        }

        return "\( version.majorVersion ).\( version.minorVersion )"
    }
}
