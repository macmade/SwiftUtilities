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

struct Test_XPCUpdateInstaller
{
    private struct StubError: Error, Equatable
    {}

    private static let identity = CodeSigningIdentity( identifier: "com.example.App", teamIdentifier: "ABCDE12345" )

    private struct StubInspector: CodeSignatureInspecting
    {
        let error: ( any Error & Sendable )?

        init( error: ( any Error & Sendable )? = nil )
        {
            self.error = error
        }

        func runningApplicationIdentity() throws -> CodeSigningIdentity
        {
            if let error = self.error
            {
                throw error
            }

            return Test_XPCUpdateInstaller.identity
        }

        func verify( bundleAt url: URL, satisfies requirement: String ) throws
        {}
    }

    private final class StubConnector: UpdaterServiceConnecting, @unchecked Sendable
    {
        let resultData:     Data
        let progressPhases: [ InstallProgress ]

        private( set ) var receivedRequest: Data?

        init( resultData: Data, progressPhases: [ InstallProgress ] = [] )
        {
            self.resultData     = resultData
            self.progressPhases = progressPhases
        }

        func installUpdate( _ request: Data, progress: @escaping @Sendable ( Data ) -> Void ) async throws -> Data
        {
            self.receivedRequest = request

            try self.progressPhases.forEach
            {
                progress( try $0.encoded() )
            }

            return self.resultData
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

    @Test
    func forwardsRequestAndReportsSuccess() async throws
    {
        let connector = StubConnector( resultData: try UpdateInstallResult.success.encoded(), progressPhases: [ .extracting, .validating, .replacing ] )
        let collector = ProgressCollector()
        let installer = XPCUpdateInstaller( inspector: StubInspector(), connector: connector, processIdentifier: 4242 )

        try await installer.install( archive: URL( fileURLWithPath: "/tmp/App.zip" ), format: .zip, replacing: URL( fileURLWithPath: "/Applications/App.app" ), into: FileManager.default.temporaryDirectory ) { collector.record( $0 ) }

        let request = try UpdateInstallRequest.decoded( from: #require( connector.receivedRequest ) )

        #expect( request.archiveURL        == URL( fileURLWithPath: "/tmp/App.zip" ) )
        #expect( request.targetURL         == URL( fileURLWithPath: "/Applications/App.app" ) )
        #expect( request.identity          == Test_XPCUpdateInstaller.identity )
        #expect( request.format            == .zip )
        #expect( request.processIdentifier == 4242 )
        #expect( collector.values          == [ .extracting, .validating, .replacing ] )
    }

    @Test
    func throwsWhenTheServiceReportsFailure() async throws
    {
        let connector = StubConnector( resultData: try UpdateInstallResult.failure( reason: "The update could not be installed." ).encoded() )
        let installer = XPCUpdateInstaller( inspector: StubInspector(), connector: connector, processIdentifier: 1 )

        await #expect( throws: UpdateInstallError.installationFailed( reason: "The update could not be installed." ) )
        {
            try await installer.install( archive: URL( fileURLWithPath: "/tmp/App.zip" ), format: .zip, replacing: URL( fileURLWithPath: "/Applications/App.app" ), into: FileManager.default.temporaryDirectory ) { _ in }
        }
    }

    @Test
    func propagatesIdentityFailureWithoutConnecting() async
    {
        let connector = StubConnector( resultData: Data() )
        let installer = XPCUpdateInstaller( inspector: StubInspector( error: StubError() ), connector: connector, processIdentifier: 1 )

        await #expect( throws: StubError.self )
        {
            try await installer.install( archive: URL( fileURLWithPath: "/tmp/App.zip" ), format: .zip, replacing: URL( fileURLWithPath: "/Applications/App.app" ), into: FileManager.default.temporaryDirectory ) { _ in }
        }

        #expect( connector.receivedRequest == nil )
    }
}
