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
    import SwiftUI

    /// Hosts the update-available window and owns its lifetime.
    ///
    /// ``GitHubUpdater`` is a `Sendable` value type with no mutable state, so it
    /// cannot itself retain a window. Instead it calls the type method
    /// ``show(applicationName:currentVersion:updateVersion:notes:downloadURL:releaseURL:)``,
    /// which guarantees a single update window: the live controller is held in a
    /// shared reference, so a repeated check brings the existing window to the
    /// front instead of opening another. The controller releases itself when the
    /// window closes (via `NSWindowDelegate`).
    @MainActor
    internal final class UpdateWindowController: NSObject, NSWindowDelegate
    {
        /// The default content size of the window.
        private static let contentSize = NSSize( width: 540, height: 460 )

        /// The single live controller, or `nil` when no update window is open.
        ///
        /// Holding the controller here both enforces the single-window rule and
        /// keeps the controller alive while its window is on screen.
        private static var shared: UpdateWindowController?

        /// The hosted window, while it is on screen.
        private var window: NSWindow?

        /// Shows the update-available window, reusing the existing one if open.
        ///
        /// If a window is already on screen, it is simply brought to the front;
        /// otherwise a new one is created, centered, and shown.
        ///
        /// - Parameters:
        ///   - applicationName: The display name of the application.
        ///   - currentVersion:  The current version of the application.
        ///   - updateVersion:   The version of the available update.
        ///   - notes:           The release's Markdown notes.
        ///   - downloadURL:     The direct download URL, or `nil` when the release
        ///                      has no downloadable asset.
        ///   - releaseURL:      The URL of the release page on GitHub.
        static func show(
            applicationName: String,
            currentVersion:  String,
            updateVersion:   String,
            notes:           String,
            downloadURL:     URL?,
            releaseURL:      URL
        )
        {
            if let shared = UpdateWindowController.shared
            {
                shared.bringToFront()

                return
            }

            let controller = UpdateWindowController()

            UpdateWindowController.shared = controller

            controller.present(
                applicationName: applicationName,
                currentVersion:  currentVersion,
                updateVersion:   updateVersion,
                notes:           notes,
                downloadURL:     downloadURL,
                releaseURL:      releaseURL
            )
        }

        /// Builds, centers, and shows the window for the given release.
        ///
        /// - Parameters:
        ///   - applicationName: The display name of the application.
        ///   - currentVersion:  The current version of the application.
        ///   - updateVersion:   The version of the available update.
        ///   - notes:           The release's Markdown notes.
        ///   - downloadURL:     The direct download URL, or `nil`.
        ///   - releaseURL:      The URL of the release page on GitHub.
        private func present(
            applicationName: String,
            currentVersion:  String,
            updateVersion:   String,
            notes:           String,
            downloadURL:     URL?,
            releaseURL:      URL
        )
        {
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
                    [ weak self ] in self?.close()
                }
            )

            let window         = NSWindow( contentViewController: NSHostingController( rootView: view ) )
            window.title       = Localization.string( "GitHubUpdater.window.title" )
            window.delegate    = self
            window.isReleasedWhenClosed = false

            // Size the window before centering, so the SwiftUI content does not
            // resize it away from the centered position afterwards.
            window.setContentSize( UpdateWindowController.contentSize )
            window.center()

            self.window = window

            self.bringToFront()
        }

        /// Activates the application and brings the window to the front.
        private func bringToFront()
        {
            NSApp.activate( ignoringOtherApps: true )
            self.window?.makeKeyAndOrderFront( nil )
        }

        /// Closes the hosted window, which in turn releases the controller.
        private func close()
        {
            self.window?.close()
        }

        /// Releases the window and the shared controller reference when the window closes.
        ///
        /// - Parameter notification: The `NSWindow.willCloseNotification` notification.
        func windowWillClose( _ notification: Notification )
        {
            self.window                   = nil
            UpdateWindowController.shared = nil
        }
    }

#endif
