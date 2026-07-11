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

            /// The update is installed and ready; waiting for the user to relaunch.
            case installed

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
                    case .installed:   return 3
                    case .relaunching: return 4
                    case .failed:      return 5
                }
            }
        }

        /// The current phase of the flow.
        public private( set ) var state: State = .idle

        /// Whether the flow is in an active phase the user must not interrupt.
        ///
        /// True while downloading, installing, or relaunching — the phases with no
        /// action buttons, during which the window must not be closed (closing would
        /// not stop the work, and a successful install still relaunches). The window
        /// disables its close control while this is `true`.
        public var isBusy: Bool
        {
            switch self.state
            {
                case .downloading, .installing, .relaunching:

                    return true

                case .idle, .installed, .failed:

                    return false
            }
        }

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

        /// Stages the relaunch helper before the install replaces the application.
        private let stageRelaunch: @Sendable () -> Void

        /// Spawns the staged relaunch helper for this application (client-side).
        private let scheduleRelaunch: @Sendable () async throws -> Void

        /// Terminates the application to trigger the relaunch.
        private let terminate: @MainActor () -> Void

        /// Creates a view model from its injected dependencies.
        ///
        /// - Parameters:
        ///   - downloader:       Downloads the asset.
        ///   - installer:        Installs the downloaded asset.
        ///   - downloadURL:      The asset's download URL.
        ///   - format:           The asset's archive format.
        ///   - target:           The application bundle to replace.
        ///   - stageRelaunch:    Stages the relaunch helper before the install
        ///                       replaces the application. Best-effort; defaults to a
        ///                       no-op.
        ///   - scheduleRelaunch: Spawns the staged relaunch helper (client-side).
        ///   - terminate:        Terminates the application to trigger the relaunch.
        ///   - state:            The initial state. Defaults to ``State/idle``; other
        ///                       values are only useful for previews.
        init( downloader: UpdateDownloading, installer: UpdateInstaller, downloadURL: URL, format: UpdateArchiveFormat, target: URL, stageRelaunch: @escaping @Sendable () -> Void = {}, scheduleRelaunch: @escaping @Sendable () async throws -> Void, terminate: @escaping @MainActor () -> Void, state: State = .idle )
        {
            self.downloader       = downloader
            self.installer        = installer
            self.downloadURL      = downloadURL
            self.format           = format
            self.target           = target
            self.stageRelaunch    = stageRelaunch
            self.scheduleRelaunch = scheduleRelaunch
            self.terminate        = terminate
            self.state            = state
        }

        /// Runs the update flow up to the point of relaunch, or to a failure.
        ///
        /// First stages the relaunch helper — this must happen before the install
        /// replaces the application, while the helper is still on disk. Then downloads
        /// the asset and installs it (which, off the sandbox, validates and replaces
        /// the application on disk). On success the state becomes ``State/installed``
        /// and the flow **stops there**: the application keeps running until the user
        /// asks to relaunch via ``relaunch()``. On any error the state becomes
        /// ``State/failed(message:)`` and the application is left running.
        public func start() async
        {
            // Stage the relaunch helper before anything replaces the application; the
            // relaunch is then driven by the app itself, not the service.
            self.stageRelaunch()

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

                self.advance( to: .installed )
            }
            catch
            {
                self.advance( to: .failed( message: InAppUpdateViewModel.message( for: error ) ) )
            }
        }

        /// Relaunches into the newly installed version, on the user's request.
        ///
        /// Spawns the staged relaunch helper (the app drives its own relaunch — the
        /// updater service cannot, having just replaced its own bundle) and then
        /// terminates the application so that helper reopens the new version. Because
        /// the relaunch is spawned only here, choosing not to relaunch leaves nothing
        /// pending. If spawning fails, the state becomes ``State/failed(message:)`` and
        /// the application keeps running (the update is already installed). Intended to
        /// be called from the ``State/installed`` state.
        ///
        /// If the termination is *refused* — an `applicationShouldTerminate` delegate
        /// returning `.terminateCancel`, or a cancelled unsaved-changes sheet — the
        /// state is returned to ``State/installed`` so the user is not stranded on a
        /// buttonless "Relaunching…" spinner. (A successful quit exits the process, so
        /// the recovery below is only reached when the quit did not happen.)
        public func relaunch() async
        {
            self.advance( to: .relaunching )

            do
            {
                try await self.scheduleRelaunch()

                self.terminate()

                // Reached only if the quit was refused; a successful quit never
                // returns here. Restore the installed state (a deliberate backward
                // transition, so it bypasses `advance(to:)`) to re-show the actions.
                self.state = .installed
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
        /// Every install phase is shown as ``State/installing``; the user-facing
        /// ``State/relaunching`` happens only once the user asks to relaunch, which
        /// is arranged separately from the install (see ``relaunch()``).
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
            /// hand-off to the bundled service for the install. The relaunch is driven
            /// by the app itself: the service's bundle is staged to a cache before the
            /// install replaces the application, and the user's relaunch request spawns
            /// that staged copy directly, then terminates the application. The service
            /// is not contacted after the install — having replaced its own bundle, it
            /// cannot safely keep running.
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

                let processIdentifier = ProcessInfo.processInfo.processIdentifier

                self.init(
                    downloader:       UpdateDownloader(),
                    installer:        XPCUpdateInstaller(),
                    downloadURL:      downloadURL,
                    format:           format,
                    target:           target,
                    stageRelaunch:
                    {
                        guard let service = UpdaterServiceLocator.serviceURL
                        else
                        {
                            return
                        }

                        _ = try? ProcessRelauncher.stageRelaunchBundle( forApplicationAt: target, from: service )
                    },
                    scheduleRelaunch: { try ProcessRelauncher.spawnStagedRelaunch( forApplicationAt: target, waitingFor: processIdentifier ) },
                    terminate:        { NSApplication.shared.terminate( nil ) }
                )
            }
        }

    #endif

#endif
