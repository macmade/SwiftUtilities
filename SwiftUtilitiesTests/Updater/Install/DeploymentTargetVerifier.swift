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
@testable import SwiftUtilities
import Testing

struct Test_DeploymentTargetVerifier
{
    /// Builds a throwaway application bundle whose `Info.plist` declares the given
    /// `LSMinimumSystemVersion` (or none, when `nil`), returning its URL.
    ///
    /// The caller is responsible for removing the returned directory.
    ///
    /// - Parameters:
    ///   - minimumSystemVersion: The value for `LSMinimumSystemVersion`, or `nil` to
    ///                           omit the key entirely.
    ///   - writeInfoPlist:       Whether to write `Contents/Info.plist` at all.
    private func makeBundle( minimumSystemVersion: String?, writeInfoPlist: Bool = true ) throws -> URL
    {
        let root     = URL( fileURLWithPath: NSTemporaryDirectory(), isDirectory: true ).appendingPathComponent( "DeploymentTargetVerifierTests.\( UUID().uuidString ).app", isDirectory: true )
        let contents = root.appendingPathComponent( "Contents", isDirectory: true )

        try FileManager.default.createDirectory( at: contents, withIntermediateDirectories: true )

        if writeInfoPlist
        {
            var info: [ String: Any ] = [ "CFBundleName": "App" ]

            if let minimumSystemVersion
            {
                info[ "LSMinimumSystemVersion" ] = minimumSystemVersion
            }

            let data = try PropertyListSerialization.data( fromPropertyList: info, format: .xml, options: 0 )

            try data.write( to: contents.appendingPathComponent( "Info.plist" ) )
        }

        return root
    }

    /// A host operating-system version for injection.
    private func host( _ major: Int, _ minor: Int, _ patch: Int = 0 ) -> OperatingSystemVersion
    {
        OperatingSystemVersion( majorVersion: major, minorVersion: minor, patchVersion: patch )
    }

    @Test
    func passesWhenHostIsNewer() throws
    {
        let bundle = try self.makeBundle( minimumSystemVersion: "13.0" )

        defer { try? FileManager.default.removeItem( at: bundle ) }

        let verifier = DeploymentTargetVerifier( host: self.host( 14, 0 ) )

        #expect( throws: Never.self )
        {
            try verifier.verify( bundle: bundle )
        }
    }

    @Test
    func passesWhenHostEqualsRequirement() throws
    {
        let bundle = try self.makeBundle( minimumSystemVersion: "13.4" )

        defer { try? FileManager.default.removeItem( at: bundle ) }

        let verifier = DeploymentTargetVerifier( host: self.host( 13, 4 ) )

        #expect( throws: Never.self )
        {
            try verifier.verify( bundle: bundle )
        }
    }

    @Test
    func throwsWhenHostIsTooOld() throws
    {
        let bundle = try self.makeBundle( minimumSystemVersion: "14.0" )

        defer { try? FileManager.default.removeItem( at: bundle ) }

        let verifier = DeploymentTargetVerifier( host: self.host( 13, 0 ) )

        #expect( throws: DeploymentTargetError.self )
        {
            try verifier.verify( bundle: bundle )
        }
    }

    @Test
    func usesNumericOrderingNotStringOrdering() throws
    {
        let bundle = try self.makeBundle( minimumSystemVersion: "13.10" )

        defer { try? FileManager.default.removeItem( at: bundle ) }

        // A string comparison would rank "13.9" >= "13.10"; a numeric one does not.
        let tooOld = DeploymentTargetVerifier( host: self.host( 13, 9 ) )
        let newer  = DeploymentTargetVerifier( host: self.host( 13, 10 ) )

        #expect( throws: DeploymentTargetError.self )
        {
            try tooOld.verify( bundle: bundle )
        }

        #expect( throws: Never.self )
        {
            try newer.verify( bundle: bundle )
        }
    }

    @Test
    func considersThePatchComponent() throws
    {
        let bundle = try self.makeBundle( minimumSystemVersion: "13.0.1" )

        defer { try? FileManager.default.removeItem( at: bundle ) }

        let tooOld = DeploymentTargetVerifier( host: self.host( 13, 0, 0 ) )
        let newer  = DeploymentTargetVerifier( host: self.host( 13, 0, 1 ) )

        #expect( throws: DeploymentTargetError.self )
        {
            try tooOld.verify( bundle: bundle )
        }

        #expect( throws: Never.self )
        {
            try newer.verify( bundle: bundle )
        }
    }

    @Test
    func passesWhenKeyIsMissing() throws
    {
        let bundle = try self.makeBundle( minimumSystemVersion: nil )

        defer { try? FileManager.default.removeItem( at: bundle ) }

        let verifier = DeploymentTargetVerifier( host: self.host( 10, 0 ) )

        #expect( throws: Never.self )
        {
            try verifier.verify( bundle: bundle )
        }
    }

    @Test
    func passesWhenValueIsUnparseable() throws
    {
        let bundle = try self.makeBundle( minimumSystemVersion: "not-a-version" )

        defer { try? FileManager.default.removeItem( at: bundle ) }

        let verifier = DeploymentTargetVerifier( host: self.host( 10, 0 ) )

        #expect( throws: Never.self )
        {
            try verifier.verify( bundle: bundle )
        }
    }

    @Test
    func passesWhenInfoPlistIsMissing() throws
    {
        let bundle = try self.makeBundle( minimumSystemVersion: nil, writeInfoPlist: false )

        defer { try? FileManager.default.removeItem( at: bundle ) }

        let verifier = DeploymentTargetVerifier( host: self.host( 10, 0 ) )

        #expect( throws: Never.self )
        {
            try verifier.verify( bundle: bundle )
        }
    }

    @Test
    func errorNamesRequiredAndHostVersions() throws
    {
        let bundle = try self.makeBundle( minimumSystemVersion: "14.2" )

        defer { try? FileManager.default.removeItem( at: bundle ) }

        let verifier = DeploymentTargetVerifier( host: self.host( 13, 1 ) )

        do
        {
            try verifier.verify( bundle: bundle )
            Issue.record( "Expected verification to throw" )
        }
        catch let error as DeploymentTargetError
        {
            #expect( error == .incompatible( required: "14.2", host: "13.1" ) )

            let description = try #require( error.errorDescription )

            #expect( description.contains( "14.2" ) )
            #expect( description.contains( "13.1" ) )
        }
    }

    @Test( arguments: [ "", ".5", "13.", "13..4", "not-a-version", "13.x", "v13.0", ".." ] )
    func allowsMalformedVersion( _ value: String ) throws
    {
        let bundle = try self.makeBundle( minimumSystemVersion: value )

        defer { try? FileManager.default.removeItem( at: bundle ) }

        // The host is far older than any plausible requirement, so a parsed value
        // would throw; leniency means an unparseable one never does.
        let verifier = DeploymentTargetVerifier( host: self.host( 1, 0 ) )

        #expect( throws: Never.self )
        {
            try verifier.verify( bundle: bundle )
        }
    }

    @Test
    func trimsSurroundingWhitespace() throws
    {
        let bundle = try self.makeBundle( minimumSystemVersion: "  14.0  " )

        defer { try? FileManager.default.removeItem( at: bundle ) }

        // Trimming must let this parse as 14.0, so a 13.0 host is too old while a
        // 14.0 host is not.
        let tooOld = DeploymentTargetVerifier( host: self.host( 13, 0 ) )
        let newer  = DeploymentTargetVerifier( host: self.host( 14, 0 ) )

        #expect( throws: DeploymentTargetError.self )
        {
            try tooOld.verify( bundle: bundle )
        }

        #expect( throws: Never.self )
        {
            try newer.verify( bundle: bundle )
        }
    }
}
