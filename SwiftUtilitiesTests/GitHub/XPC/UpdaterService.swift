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

struct Test_UpdaterService
{
    private struct StubError: Error, Equatable
    {}

    private final class StubExtractor: ArchiveExtracting, @unchecked Sendable
    {
        let result: URL
        let error:  ( any Error & Sendable )?

        init( result: URL, error: ( any Error & Sendable )? = nil )
        {
            self.result = result
            self.error  = error
        }

        func extractApplication( from archive: URL, format: UpdateArchiveFormat, into workingDirectory: URL ) async throws -> URL
        {
            if let error = self.error
            {
                throw error
            }

            return self.result
        }
    }

    private final class StubInspector: CodeSignatureInspecting, @unchecked Sendable
    {
        let verificationFails: Bool

        private( set ) var verifiedURL:         URL?
        private( set ) var verifiedRequirement: String?

        init( verificationFails: Bool = false )
        {
            self.verificationFails = verificationFails
        }

        func runningApplicationIdentity() throws -> CodeSigningIdentity
        {
            CodeSigningIdentity( identifier: "com.example.Service", teamIdentifier: "ZZZZZ00000" )
        }

        func verify( bundleAt url: URL, satisfies requirement: String ) throws
        {
            self.verifiedURL         = url
            self.verifiedRequirement = requirement

            if self.verificationFails
            {
                throw StubError()
            }
        }
    }

    private final class StubReplacer: AppReplacing, @unchecked Sendable
    {
        let installed: URL

        private( set ) var target:      URL?
        private( set ) var replacement: URL?

        init( installed: URL )
        {
            self.installed = installed
        }

        func replaceApplication( at target: URL, with replacement: URL ) throws -> URL
        {
            self.target      = target
            self.replacement = replacement

            return self.installed
        }
    }

    private final class StubRelauncher: ApplicationRelaunching, @unchecked Sendable
    {
        private( set ) var relaunched: URL?

        func relaunch( _ application: URL ) throws
        {
            self.relaunched = application
        }
    }

    private final class RelauncherFactory: @unchecked Sendable
    {
        let relauncher = StubRelauncher()

        private( set ) var requestedProcessIdentifier: Int32?

        func make( _ processIdentifier: Int32 ) -> ApplicationRelaunching
        {
            self.requestedProcessIdentifier = processIdentifier

            return self.relauncher
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

    private static let identity = CodeSigningIdentity( identifier: "com.example.App", teamIdentifier: "ABCDE12345" )

    private static func request( format: UpdateArchiveFormat = .zip, processIdentifier: Int32 = 9182 ) -> UpdateInstallRequest
    {
        UpdateInstallRequest(
            archive:           URL( fileURLWithPath: "/tmp/Update.zip" ),
            target:            URL( fileURLWithPath: "/Applications/App.app" ),
            identity:          Test_UpdaterService.identity,
            format:            format,
            processIdentifier: processIdentifier
        )
    }

    @Test
    func runInstallsAndReportsSuccess() async throws
    {
        let candidate = URL( fileURLWithPath: "/tmp/New.app" )
        let installed = URL( fileURLWithPath: "/Applications/App.app" )
        let extractor = StubExtractor( result: candidate )
        let inspector = StubInspector()
        let replacer  = StubReplacer( installed: installed )
        let factory   = RelauncherFactory()
        let progress  = ProgressCollector()

        let result = await UpdaterService.run(
            request:        try Test_UpdaterService.request( processIdentifier: 4242 ).encoded(),
            extractor:      extractor,
            inspector:      inspector,
            replacer:       replacer,
            makeRelauncher: { factory.make( $0 ) },
            reportProgress: { progress.record( $0 ) }
        )

        #expect( result == .success )
        #expect( progress.values == [ .extracting, .validating, .replacing, .relaunching ] )

        // The candidate is validated against the requirement rebuilt from the
        // request's identity — not the service's own identity.
        #expect( inspector.verifiedURL         == candidate )
        #expect( inspector.verifiedRequirement == Test_UpdaterService.identity.requirement )

        #expect( replacer.target                    == URL( fileURLWithPath: "/Applications/App.app" ) )
        #expect( replacer.replacement               == candidate )
        #expect( factory.requestedProcessIdentifier == 4242 )
        #expect( factory.relauncher.relaunched      == installed )
    }

    @Test
    func runReportsFailureAndDoesNotReplaceWhenValidationFails() async throws
    {
        let extractor = StubExtractor( result: URL( fileURLWithPath: "/tmp/New.app" ) )
        let inspector = StubInspector( verificationFails: true )
        let replacer  = StubReplacer( installed: URL( fileURLWithPath: "/Applications/App.app" ) )
        let factory   = RelauncherFactory()
        let progress  = ProgressCollector()

        let result = await UpdaterService.run(
            request:        try Test_UpdaterService.request().encoded(),
            extractor:      extractor,
            inspector:      inspector,
            replacer:       replacer,
            makeRelauncher: { factory.make( $0 ) },
            reportProgress: { progress.record( $0 ) }
        )

        #expect( result == .failure( from: StubError() ) )
        #expect( replacer.target == nil )
        #expect( factory.relauncher.relaunched == nil )
        #expect( progress.values == [ .extracting, .validating ] )
    }

    @Test
    func runReportsFailureWhenExtractionFails() async throws
    {
        let extractor = StubExtractor( result: URL( fileURLWithPath: "/tmp/New.app" ), error: StubError() )
        let inspector = StubInspector()
        let replacer  = StubReplacer( installed: URL( fileURLWithPath: "/Applications/App.app" ) )
        let factory   = RelauncherFactory()
        let progress  = ProgressCollector()

        let result = await UpdaterService.run(
            request:        try Test_UpdaterService.request().encoded(),
            extractor:      extractor,
            inspector:      inspector,
            replacer:       replacer,
            makeRelauncher: { factory.make( $0 ) },
            reportProgress: { progress.record( $0 ) }
        )

        #expect( result == .failure( from: StubError() ) )
        #expect( inspector.verifiedURL == nil )
        #expect( replacer.target == nil )
        #expect( progress.values == [ .extracting ] )
    }

    @Test
    func runReportsFailureWhenTheRequestCannotBeDecoded() async
    {
        let factory = RelauncherFactory()

        let result = await UpdaterService.run(
            request:        Data( "not a request".utf8 ),
            extractor:      StubExtractor( result: URL( fileURLWithPath: "/tmp/New.app" ) ),
            inspector:      StubInspector(),
            replacer:       StubReplacer( installed: URL( fileURLWithPath: "/Applications/App.app" ) ),
            makeRelauncher: { factory.make( $0 ) },
            reportProgress: { _ in }
        )

        guard case .failure = result
        else
        {
            Issue.record( "Expected a failure result for undecodable request data." )

            return
        }

        #expect( factory.requestedProcessIdentifier == nil )
    }

    @Test
    func installUpdateRepliesWithTheEncodedResult() async throws
    {
        let candidate = URL( fileURLWithPath: "/tmp/New.app" )
        let service   = UpdaterService(
            extractor:      StubExtractor( result: candidate ),
            inspector:      StubInspector(),
            replacer:       StubReplacer( installed: URL( fileURLWithPath: "/Applications/App.app" ) ),
            makeRelauncher: { _ in StubRelauncher() },
            reportProgress: { _ in }
        )

        let requestData = try Test_UpdaterService.request().encoded()

        let replyData = await withCheckedContinuation
        {
            continuation in

            service.installUpdate( requestData )
            {
                continuation.resume( returning: $0 )
            }
        }

        #expect( try UpdateInstallResult.decoded( from: replyData ) == .success )
    }
}
