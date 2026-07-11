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

struct Test_UpdateInstallation
{
    private struct StubError: Error, Equatable
    {}

    private final class StubExtractor: ArchiveExtracting, @unchecked Sendable
    {
        let result: URL
        let error:  ( any Error & Sendable )?

        private( set ) var called = false

        init( result: URL, error: ( any Error & Sendable )? = nil )
        {
            self.result = result
            self.error  = error
        }

        func extractApplication( from archive: URL, format: UpdateArchiveFormat, into workingDirectory: URL ) async throws -> URL
        {
            self.called = true

            if let error = self.error
            {
                throw error
            }

            return self.result
        }
    }

    private final class StubReplacer: AppReplacing, @unchecked Sendable
    {
        let installed: URL?
        let error:     ( any Error & Sendable )?

        private( set ) var target:      URL?
        private( set ) var replacement: URL?

        init( installed: URL? = nil, error: ( any Error & Sendable )? = nil )
        {
            self.installed = installed
            self.error     = error
        }

        func replaceApplication( at target: URL, with replacement: URL ) throws -> URL
        {
            self.target      = target
            self.replacement = replacement

            if let error = self.error
            {
                throw error
            }

            return self.installed ?? target
        }
    }

    private final class ProgressCollector: @unchecked Sendable
    {
        private( set ) var values: [ InstallProgress ] = []

        func record( _ progress: InstallProgress )
        {
            self.values.append( progress )
        }
    }

    /// An inspector whose verification passes or fails deterministically.
    private struct StubInspector: CodeSignatureInspecting
    {
        let verificationSucceeds: Bool

        func runningApplicationIdentity() throws -> CodeSigningIdentity
        {
            CodeSigningIdentity( identifier: "com.example.App", teamIdentifier: "ABCDE12345" )
        }

        func verify( bundleAt url: URL, satisfies requirement: String ) throws
        {
            guard self.verificationSucceeds
            else
            {
                throw StubError()
            }
        }
    }

    private func makeInstaller( extractor: StubExtractor, verificationSucceeds: Bool = true, replacer: StubReplacer ) -> UpdateInstallation
    {
        UpdateInstallation(
            extractor: extractor,
            validator: CodeSignatureValidator( inspector: StubInspector( verificationSucceeds: verificationSucceeds ) ),
            replacer:  replacer
        )
    }

    @Test
    func installComposesStepsInOrder() async throws
    {
        let candidate = URL( fileURLWithPath: "/tmp/New.app" )
        let target    = URL( fileURLWithPath: "/Applications/App.app" )
        let archive   = URL( fileURLWithPath: "/tmp/App.zip" )
        let extractor = StubExtractor( result: candidate )
        let replacer  = StubReplacer()
        let progress  = ProgressCollector()
        let installer = self.makeInstaller( extractor: extractor, replacer: replacer )

        try await installer.install( archive: archive, format: .zip, replacing: target, into: FileManager.default.temporaryDirectory ) { progress.record( $0 ) }

        #expect( extractor.called )
        #expect( replacer.target      == target )
        #expect( replacer.replacement == candidate )
        #expect( progress.values == [ .extracting, .validating, .replacing ] )
    }

    @Test
    func installRefusesToReplaceOnValidationFailure() async throws
    {
        let candidate  = URL( fileURLWithPath: "/tmp/New.app" )
        let target     = URL( fileURLWithPath: "/Applications/App.app" )
        let archive    = URL( fileURLWithPath: "/tmp/App.zip" )
        let extractor = StubExtractor( result: candidate )
        let replacer  = StubReplacer()
        let progress  = ProgressCollector()
        let installer = self.makeInstaller( extractor: extractor, verificationSucceeds: false, replacer: replacer )

        await #expect( throws: ( any Error ).self )
        {
            try await installer.install( archive: archive, format: .zip, replacing: target, into: FileManager.default.temporaryDirectory ) { progress.record( $0 ) }
        }

        #expect( replacer.target == nil )
        #expect( progress.values == [ .extracting, .validating ] )
    }

    @Test
    func installStopsWhenExtractionFails() async throws
    {
        let target     = URL( fileURLWithPath: "/Applications/App.app" )
        let archive    = URL( fileURLWithPath: "/tmp/App.zip" )
        let extractor = StubExtractor( result: URL( fileURLWithPath: "/tmp/New.app" ), error: StubError() )
        let replacer  = StubReplacer()
        let progress  = ProgressCollector()
        let installer = self.makeInstaller( extractor: extractor, replacer: replacer )

        await #expect( throws: StubError.self )
        {
            try await installer.install( archive: archive, format: .zip, replacing: target, into: FileManager.default.temporaryDirectory ) { progress.record( $0 ) }
        }

        #expect( replacer.target == nil )
        #expect( progress.values == [ .extracting ] )
    }

    @Test
    func installStopsWhenReplacementFails() async throws
    {
        let candidate = URL( fileURLWithPath: "/tmp/New.app" )
        let target    = URL( fileURLWithPath: "/Applications/App.app" )
        let archive   = URL( fileURLWithPath: "/tmp/App.zip" )
        let extractor = StubExtractor( result: candidate )
        let replacer  = StubReplacer( error: StubError() )
        let progress  = ProgressCollector()
        let installer = self.makeInstaller( extractor: extractor, replacer: replacer )

        await #expect( throws: StubError.self )
        {
            try await installer.install( archive: archive, format: .zip, replacing: target, into: FileManager.default.temporaryDirectory ) { progress.record( $0 ) }
        }

        #expect( replacer.target == target )
        #expect( progress.values == [ .extracting, .validating, .replacing ] )
    }
}
