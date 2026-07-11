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

struct Test_ProcessRelauncher
{
    private final class SpawnRecorder: @unchecked Sendable
    {
        private( set ) var executable: URL?
        private( set ) var arguments:  [ String ]?

        func spawn( _ executable: URL, _ arguments: [ String ] ) throws
        {
            self.executable = executable
            self.arguments  = arguments
        }
    }

    /// Builds a minimal `.xpc`-style bundle with an executable, for staging tests.
    ///
    /// - Parameter name: The executable's name (and `CFBundleExecutable`).
    ///
    /// - Returns: A file URL to the created bundle.
    private func makeFakeBundle( executable name: String ) throws -> URL
    {
        let manager = FileManager.default
        let bundle  = manager.temporaryDirectory.appendingPathComponent( "\( name )-\( UUID().uuidString ).xpc", isDirectory: true )
        let macOS   = bundle.appendingPathComponent( "Contents/MacOS", isDirectory: true )

        try manager.createDirectory( at: macOS, withIntermediateDirectories: true )

        let executable = macOS.appendingPathComponent( name )

        try Data( "binary".utf8 ).write( to: executable )
        try manager.setAttributes( [ .posixPermissions: 0o755 ], ofItemAtPath: executable.path )

        let info = [ "CFBundleExecutable": name, "CFBundleIdentifier": "com.example.\( name )" ]
        let data = try PropertyListSerialization.data( fromPropertyList: info, format: .xml, options: 0 )

        try data.write( to: bundle.appendingPathComponent( "Contents/Info.plist" ) )

        return bundle
    }

    @Test
    func stagedBundleURLIsStableAndKeyedByTarget()
    {
        let appA = URL( fileURLWithPath: "/Applications/A.app" )
        let appB = URL( fileURLWithPath: "/Applications/B.app" )

        #expect( ProcessRelauncher.stagedBundleURL( forApplicationAt: appA ) == ProcessRelauncher.stagedBundleURL( forApplicationAt: appA ) )
        #expect( ProcessRelauncher.stagedBundleURL( forApplicationAt: appA ) != ProcessRelauncher.stagedBundleURL( forApplicationAt: appB ) )
    }

    @Test
    func stageRelaunchBundleCopiesTheWholeBundleToTheStagedLocation() throws
    {
        let target = URL( fileURLWithPath: "/Applications/StageCopyTest.app" )
        let source = try self.makeFakeBundle( executable: "Fake" )

        defer
        {
            try? FileManager.default.removeItem( at: source )
            ProcessRelauncher.removeStagedRelaunchBundle( forApplicationAt: target )
        }

        let staged = try ProcessRelauncher.stageRelaunchBundle( forApplicationAt: target, from: source )

        #expect( staged == ProcessRelauncher.stagedBundleURL( forApplicationAt: target ) )
        #expect( FileManager.default.fileExists( atPath: staged.appendingPathComponent( "Contents/MacOS/Fake" ).path ) )
        #expect( FileManager.default.fileExists( atPath: staged.appendingPathComponent( "Contents/Info.plist" ).path ) )
    }

    @Test
    func spawnStagedRelaunchSpawnsTheStagedHelperInRelaunchMode() throws
    {
        let target = URL( fileURLWithPath: "/Applications/SpawnStagedTest.app" )
        let source = try self.makeFakeBundle( executable: "Fake" )

        try ProcessRelauncher.stageRelaunchBundle( forApplicationAt: target, from: source )

        defer
        {
            try? FileManager.default.removeItem( at: source )
            ProcessRelauncher.removeStagedRelaunchBundle( forApplicationAt: target )
        }

        let recorder = SpawnRecorder()

        try ProcessRelauncher.spawnStagedRelaunch( forApplicationAt: target, waitingFor: 4242 )
        {
            try recorder.spawn( $0, $1 )
        }

        let expected = try #require( ProcessRelauncher.stagedRelaunchExecutableURL( forApplicationAt: target ) )

        #expect( recorder.executable?.path == expected.path )
        #expect( recorder.arguments        == [ ProcessRelauncher.waitArgument, "4242", target.path ] )
    }

    @Test
    func spawnStagedRelaunchThrowsWhenNothingIsStaged() throws
    {
        let target = URL( fileURLWithPath: "/Applications/SpawnStagedMissingTest.app" )

        ProcessRelauncher.removeStagedRelaunchBundle( forApplicationAt: target )

        #expect( throws: RelaunchError.relaunchHelperUnavailable )
        {
            try ProcessRelauncher.spawnStagedRelaunch( forApplicationAt: target, waitingFor: 1 ) { _, _ in }
        }
    }

    @Test
    func removeStagedRelaunchBundleClearsTheStagedCopy() throws
    {
        let target = URL( fileURLWithPath: "/Applications/StageRemoveTest.app" )
        let source = try self.makeFakeBundle( executable: "Fake" )

        defer
        {
            try? FileManager.default.removeItem( at: source )
        }

        let staged = try ProcessRelauncher.stageRelaunchBundle( forApplicationAt: target, from: source )

        #expect( FileManager.default.fileExists( atPath: staged.path ) )

        ProcessRelauncher.removeStagedRelaunchBundle( forApplicationAt: target )

        #expect( FileManager.default.fileExists( atPath: staged.path ) == false )
    }

    @Test
    func argumentsAndInvocationRoundTrip()
    {
        let invocation = ProcessRelauncher.Invocation( processIdentifier: 4242, application: URL( fileURLWithPath: "/Applications/App.app" ) )
        let arguments  = ProcessRelauncher.arguments( for: invocation )
        let decoded    = ProcessRelauncher.invocation( from: [ "/path/argv0" ] + arguments )

        #expect( decoded == invocation )
    }

    @Test
    func invocationRejectsArgumentsThatAreNotRelaunchRequests()
    {
        #expect( ProcessRelauncher.invocation( from: [ "/path/argv0" ] ) == nil )
        #expect( ProcessRelauncher.invocation( from: [ "/path/argv0", "--something-else", "1", "/App.app" ] ) == nil )
        #expect( ProcessRelauncher.invocation( from: [ "/path/argv0", ProcessRelauncher.waitArgument, "not-a-pid", "/App.app" ] ) == nil )
    }
}
