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
    import Observation
    import SwiftUI

    /// Hosts the update-available window.
    ///
    /// A thin ``HostingWindowController`` subclass: it builds the update window's
    /// content and chrome and inherits the single-window lifetime management.
    ///
    /// ``GitHubUpdater`` is a `Sendable` value type with no mutable state, so it
    /// cannot itself retain a window. Instead it calls the type method
    /// ``show(applicationName:currentVersion:updateVersion:notes:downloadURL:releaseURL:onSkip:)``,
    /// which guarantees a single update window.
    @MainActor
    public final class UpdateWindowController: HostingWindowController
    {
        /// The default content size of the window.
        private static let contentSize = NSSize( width: 540, height: 460 )

        /// Shows the update-available window, reusing the existing one if open.
        ///
        /// - Parameters:
        ///   - applicationName: The display name of the application.
        ///   - currentVersion:  The current version of the application.
        ///   - updateVersion:   The version of the available update.
        ///   - notes:           The release's Markdown notes.
        ///   - downloadURL:     The direct download URL, or `nil` when the release
        ///                      has no downloadable asset.
        ///   - releaseURL:      The URL of the release page on GitHub.
        ///   - onSkip:          Records the offered version as skipped. The window
        ///                      closes itself afterwards, so the caller only needs to
        ///                      persist the choice.
        public static func show(
            applicationName: String,
            currentVersion:  String,
            updateVersion:   String,
            notes:           String,
            downloadURL:     URL?,
            releaseURL:      URL,
            onSkip:          @escaping () -> Void
        )
        {
            HostingWindowController.show( using: UpdateWindowController.init )
            {
                controller in

                let view = UpdateAvailableView(
                    applicationName: applicationName,
                    currentVersion:  currentVersion,
                    updateVersion:   updateVersion,
                    notes:           notes,
                    downloadURL:     downloadURL,
                    onDownload:
                    {
                        if let downloadURL
                        {
                            NSWorkspace.shared.open( downloadURL )
                        }
                    },
                    onViewOnGitHub:
                    {
                        NSWorkspace.shared.open( releaseURL )
                    },
                    onLater:
                    {
                        [ weak controller ] in controller?.close()
                    },
                    onSkip:
                    {
                        [ weak controller ] in

                        onSkip()
                        controller?.close()
                    }
                )

                controller.present( rootView: view, sizing: .fixed( UpdateWindowController.contentSize ) )
                {
                    window in

                    window.title = Localization.string( "GitHubUpdater.window.title" )
                }
            }
        }

        #if !SWIFT_PACKAGE

        /// The in-app flow whose busy state gates the window's close control.
        private weak var flowModel: InAppUpdateViewModel?

        /// The hosted window whose close button is enabled or disabled.
        private weak var hostedWindow: NSWindow?

        /// Shows the in-app update window, reusing the existing one if open.
        ///
        /// Presents ``UpdateAvailableView``, driven by an ``InAppUpdateViewModel`` that
        /// downloads, installs, and relaunches in place. If the release asset is not
        /// a supported archive, it falls back to
        /// ``show(applicationName:currentVersion:updateVersion:notes:downloadURL:releaseURL:onSkip:)``,
        /// so a newer release always stays reachable.
        ///
        /// In-app updates require the Xcode framework (which bundles the updater
        /// service), so this is absent from the SwiftPM build.
        ///
        /// - Parameters:
        ///   - applicationName: The display name of the application.
        ///   - currentVersion:  The current version of the application.
        ///   - updateVersion:   The version of the available update.
        ///   - notes:           The release's Markdown notes.
        ///   - downloadURL:     The direct download URL of the release's asset.
        ///   - releaseURL:      The URL of the release page on GitHub.
        ///   - onSkip:          Records the offered version as skipped. The window
        ///                      closes itself afterwards, so the caller only needs to
        ///                      persist the choice.
        public static func showInApp(
            applicationName: String,
            currentVersion:  String,
            updateVersion:   String,
            notes:           String,
            downloadURL:     URL,
            releaseURL:      URL,
            onSkip:          @escaping () -> Void
        )
        {
            guard let model = InAppUpdateViewModel( downloadURL: downloadURL )
            else
            {
                UpdateWindowController.show(
                    applicationName: applicationName,
                    currentVersion:  currentVersion,
                    updateVersion:   updateVersion,
                    notes:           notes,
                    downloadURL:     downloadURL,
                    releaseURL:      releaseURL,
                    onSkip:          onSkip
                )

                return
            }

            HostingWindowController.show( using: UpdateWindowController.init )
            {
                controller in

                let view = UpdateAvailableView(
                    applicationName: applicationName,
                    currentVersion:  currentVersion,
                    updateVersion:   updateVersion,
                    notes:           notes,
                    downloadURL:     downloadURL,
                    model:           model,
                    onDownload:      {},
                    onViewOnGitHub:
                    {
                        NSWorkspace.shared.open( releaseURL )
                    },
                    onLater:
                    {
                        [ weak controller ] in controller?.close()
                    },
                    onSkip:
                    {
                        [ weak controller ] in

                        onSkip()
                        controller?.close()
                    }
                )

                controller.present( rootView: view, sizing: .fixed( UpdateWindowController.contentSize ) )
                {
                    window in

                    window.title = Localization.string( "GitHubUpdater.window.title" )

                    controller.trackCloseControl( for: model, in: window )
                }
            }
        }

        /// Starts keeping the window's close control in step with the in-app flow.
        ///
        /// - Parameters:
        ///   - model:  The in-app flow whose busy state drives the close control.
        ///   - window: The window whose close button to enable or disable.
        private func trackCloseControl( for model: InAppUpdateViewModel, in window: NSWindow )
        {
            self.flowModel    = model
            self.hostedWindow = window

            self.updateCloseControl()
        }

        /// Enables or disables the window's close button to match the flow.
        ///
        /// While the flow is busy (downloading / installing / relaunching) the close
        /// button is disabled, which also blocks ⌘W — closing would neither stop the
        /// work nor cancel the pending relaunch. Re-arms itself on each state change
        /// through Observation, and stops once the window or model is gone.
        private func updateCloseControl()
        {
            guard let window = self.hostedWindow, let model = self.flowModel
            else
            {
                return
            }

            withObservationTracking
            {
                window.standardWindowButton( .closeButton )?.isEnabled = ( model.isBusy == false )
            }
            onChange:
            {
                Task
                {
                    [ weak self ] in await self?.updateCloseControl()
                }
            }
        }

        #endif
    }

#endif
