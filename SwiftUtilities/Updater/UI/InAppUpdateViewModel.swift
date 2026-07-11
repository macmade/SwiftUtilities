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

    import AppKit
    import Foundation
    import Observation

    /// Drives the in-app update flow and publishes its progress to the window.
    ///
    /// Once the user chooses to update, ``start()`` runs the flow to completion:
    /// **download** the asset, hand it to the installer to **install** it (which
    /// validates, replaces, and schedules the relaunch off the sandbox), then
    /// **relaunch** by terminating the application — the running app must quit for
    /// the bundled service's detached waiter to reopen the new version. Any failure
    /// stops the flow and surfaces a readable message; the window keeps the release
    /// page reachable.
    ///
    /// The download and install steps and the terminate action are injected, so the
    /// whole state machine is unit-testable without the network, a running service,
    /// or actually quitting the app. Progress callbacks arrive on background threads
    /// and are applied on the main actor through ``advance(to:)``, which only ever
    /// moves the state forward — so a late download-progress callback can never
    /// overwrite a later phase.
    @MainActor
    @Observable
    public final class InAppUpdateViewModel
    {
        /// A phase of the in-app update flow, shown in the window.
        public enum State: Equatable, Sendable
        {
            /// Waiting for the user to start the update.
            case idle

            /// Downloading the asset, with the fraction complete when known.
            case downloading( fraction: Double? )

            /// Installing the downloaded update.
            case installing

            /// Relaunching into the new version.
            case relaunching

            /// The update failed, with a readable message.
            case failed( message: String )

            /// The forward rank of the phase, used to reject stale transitions.
            fileprivate var order: Int
            {
                switch self
                {
                    case .idle:        return 0
                    case .downloading: return 1
                    case .installing:  return 2
                    case .relaunching: return 3
                    case .failed:      return 4
                }
            }
        }

        /// The current phase of the flow.
        public private( set ) var state: State = .idle

        /// Downloads the asset.
        private let downloader: UpdateDownloading

        /// Installs the downloaded asset.
        private let installer: UpdateInstaller

        /// The asset's download URL.
        private let downloadURL: URL

        /// The asset's archive format.
        private let format: UpdateArchiveFormat

        /// The application bundle to replace (the running application).
        private let target: URL

        /// Terminates the application to trigger the relaunch.
        private let terminate: @MainActor () -> Void

        /// Creates a view model from its injected dependencies.
        ///
        /// - Parameters:
        ///   - downloader:  Downloads the asset.
        ///   - installer:   Installs the downloaded asset.
        ///   - downloadURL: The asset's download URL.
        ///   - format:      The asset's archive format.
        ///   - target:      The application bundle to replace.
        ///   - terminate:   Terminates the application to trigger the relaunch.
        ///   - state:       The initial state. Defaults to ``State/idle``; other
        ///                  values are only useful for previews.
        init( downloader: UpdateDownloading, installer: UpdateInstaller, downloadURL: URL, format: UpdateArchiveFormat, target: URL, terminate: @escaping @MainActor () -> Void, state: State = .idle )
        {
            self.downloader  = downloader
            self.installer   = installer
            self.downloadURL = downloadURL
            self.format      = format
            self.target      = target
            self.terminate   = terminate
            self.state       = state
        }

        /// Runs the update flow to completion, or to a failure.
        ///
        /// Downloads the asset, installs it, and — on success — terminates the
        /// application so the bundled service reopens the new version. On any error
        /// the state becomes ``State/failed(message:)`` and the application is left
        /// running.
        public func start() async
        {
            do
            {
                self.advance( to: .downloading( fraction: nil ) )

                let archive = try await self.downloader.download( from: self.downloadURL, into: FileManager.default.temporaryDirectory )
                {
                    progress in

                    Task
                    {
                        @MainActor in self.advance( to: .downloading( fraction: progress.fractionCompleted ) )
                    }
                }

                self.advance( to: .installing )

                try await self.installer.install( archive: archive, format: self.format, replacing: self.target, into: FileManager.default.temporaryDirectory )
                {
                    phase in

                    Task
                    {
                        @MainActor in self.advance( to: InAppUpdateViewModel.state( for: phase ) )
                    }
                }

                self.advance( to: .relaunching )

                self.terminate()
            }
            catch
            {
                self.advance( to: .failed( message: InAppUpdateViewModel.message( for: error ) ) )
            }
        }

        /// Applies a state transition, ignoring ones that would move backward.
        ///
        /// Progress callbacks are delivered asynchronously, so a stale one may arrive
        /// after the flow has already advanced. Comparing ``State/order`` keeps the
        /// state monotonic, so an out-of-order callback is dropped rather than
        /// reverting the window to an earlier phase.
        ///
        /// - Parameter state: The state to move to.
        private func advance( to state: State )
        {
            guard state.order >= self.state.order
            else
            {
                return
            }

            self.state = state
        }

        /// Maps an install phase to the flow state it should show.
        ///
        /// - Parameter phase: The installer's reported phase.
        ///
        /// - Returns: The corresponding ``State``.
        private static func state( for phase: InstallProgress ) -> State
        {
            switch phase
            {
                case .extracting, .validating, .replacing:

                    return .installing

                case .relaunching:

                    return .relaunching
            }
        }

        /// A readable message for an error, preferring its localized description.
        ///
        /// - Parameter error: The error to describe.
        ///
        /// - Returns: A user-facing message.
        private static func message( for error: any Error ) -> String
        {
            if let localized = error as? LocalizedError, let description = localized.errorDescription
            {
                return description
            }

            return error.localizedDescription
        }
    }

    #if canImport( Security )

        public extension InAppUpdateViewModel
        {
            /// Creates a production view model for an available update.
            ///
            /// Wires the real ``UpdateDownloader`` and the ``XPCUpdateInstaller``
            /// hand-off to the bundled service, and terminates the running
            /// application on success so the service reopens the new version.
            ///
            /// - Parameters:
            ///   - downloadURL: The asset's download URL. The update is only run
            ///                  in-app when this is a supported archive.
            ///   - target:      The application bundle to replace. Defaults to the
            ///                  running application.
            ///
            /// - Returns: `nil` when the asset is not a supported archive, in which
            ///   case the caller should use the link path instead.
            convenience init?( downloadURL: URL, target: URL = Bundle.main.bundleURL )
            {
                guard let format = UpdateArchiveFormat( url: downloadURL )
                else
                {
                    return nil
                }

                self.init(
                    downloader:  UpdateDownloader(),
                    installer:   XPCUpdateInstaller(),
                    downloadURL: downloadURL,
                    format:      format,
                    target:      target,
                    terminate:   { NSApplication.shared.terminate( nil ) }
                )
            }
        }

    #endif

#endif
