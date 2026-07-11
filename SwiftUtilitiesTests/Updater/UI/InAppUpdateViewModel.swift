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

#if canImport( AppKit )

    import Foundation
    @testable import SwiftUtilities
    import Testing

    @MainActor
    struct Test_InAppUpdateViewModel
    {
        private struct StubError: Error, Equatable
        {}

        private final class StubDownloader: UpdateDownloading, @unchecked Sendable
        {
            let result: URL
            let error:  ( any Error & Sendable )?

            init( result: URL, error: ( any Error & Sendable )? = nil )
            {
                self.result = result
                self.error  = error
            }

            func download( from url: URL, into directory: URL, progress: @Sendable ( DownloadProgress ) -> Void ) async throws -> URL
            {
                if let error = self.error
                {
                    throw error
                }

                return self.result
            }
        }

        private final class StubInstaller: UpdateInstaller, @unchecked Sendable
        {
            let error: ( any Error & Sendable )?

            private( set ) var archive: URL?
            private( set ) var format:  UpdateArchiveFormat?
            private( set ) var target:  URL?

            init( error: ( any Error & Sendable )? = nil )
            {
                self.error = error
            }

            func install( archive: URL, format: UpdateArchiveFormat, replacing target: URL, into workingDirectory: URL, progress: @escaping @Sendable ( InstallProgress ) -> Void ) async throws
            {
                self.archive = archive
                self.format  = format
                self.target  = target

                if let error = self.error
                {
                    throw error
                }
            }
        }

        private final class Terminator
        {
            private( set ) var count = 0

            func record()
            {
                self.count += 1
            }
        }

        private func makeModel( downloader: StubDownloader, installer: StubInstaller, format: UpdateArchiveFormat = .zip, target: URL = URL( fileURLWithPath: "/Applications/App.app" ), terminate: @escaping @MainActor () -> Void ) -> InAppUpdateViewModel
        {
            InAppUpdateViewModel(
                downloader:  downloader,
                installer:   installer,
                downloadURL: URL( fileURLWithPath: "/tmp/App.zip" ),
                format:      format,
                target:      target,
                terminate:   terminate
            )
        }

        @Test
        func runsToRelaunchAndTerminatesOnSuccess() async
        {
            let terminator = Terminator()
            let model      = self.makeModel( downloader: StubDownloader( result: URL( fileURLWithPath: "/tmp/New.app" ) ), installer: StubInstaller() ) { terminator.record() }

            await model.start()

            #expect( model.state == .relaunching )
            #expect( terminator.count == 1 )
        }

        @Test
        func handsTheDownloadedArchiveToTheInstaller() async
        {
            let archive   = URL( fileURLWithPath: "/tmp/downloaded/App.dmg" )
            let installer = StubInstaller()
            let model     = self.makeModel( downloader: StubDownloader( result: archive ), installer: installer, format: .dmg, target: URL( fileURLWithPath: "/Applications/App.app" ) ) {}

            await model.start()

            #expect( installer.archive == archive )
            #expect( installer.format  == .dmg )
            #expect( installer.target  == URL( fileURLWithPath: "/Applications/App.app" ) )
        }

        @Test
        func failsAndDoesNotInstallOrTerminateWhenDownloadFails() async
        {
            let terminator = Terminator()
            let installer  = StubInstaller()
            let model      = self.makeModel( downloader: StubDownloader( result: URL( fileURLWithPath: "/tmp/New.app" ), error: StubError() ), installer: installer ) { terminator.record() }

            await model.start()

            guard case .failed = model.state
            else
            {
                Issue.record( "Expected a failed state after a download failure." )

                return
            }

            #expect( installer.archive == nil )
            #expect( terminator.count == 0 )
        }

        @Test
        func failsAndDoesNotTerminateWhenInstallFails() async
        {
            let terminator = Terminator()
            let model      = self.makeModel( downloader: StubDownloader( result: URL( fileURLWithPath: "/tmp/New.app" ) ), installer: StubInstaller( error: StubError() ) ) { terminator.record() }

            await model.start()

            guard case .failed = model.state
            else
            {
                Issue.record( "Expected a failed state after an install failure." )

                return
            }

            #expect( terminator.count == 0 )
        }

        @Test
        func startsIdle()
        {
            let model = self.makeModel( downloader: StubDownloader( result: URL( fileURLWithPath: "/tmp/New.app" ) ), installer: StubInstaller() ) {}

            #expect( model.state == .idle )
        }
    }

#endif
