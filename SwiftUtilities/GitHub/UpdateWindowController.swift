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
    /// cannot itself retain a window. Instead it creates a controller and calls
    /// ``show(applicationName:currentVersion:updateVersion:notes:downloadURL:releaseURL:)``;
    /// the controller self-retains while its non-modal window is on screen and
    /// releases itself when the window closes (via `NSWindowDelegate`).
    @MainActor
    internal final class UpdateWindowController: NSObject, NSWindowDelegate
    {
        /// The hosted window, while it is on screen.
        private var window: NSWindow?

        /// A strong reference to `self`, keeping the controller alive while the
        /// window is on screen. Cleared when the window closes.
        private var retained: UpdateWindowController?

        /// Builds and shows the update-available window.
        ///
        /// The window hosts an ``UpdateAvailableView`` whose actions are wired to
        /// open the download or release URL in the default browser and to dismiss
        /// the window. The application is brought to the front so the non-modal
        /// window is visible.
        ///
        /// - Parameters:
        ///   - applicationName: The display name of the application.
        ///   - currentVersion:  The current version of the application.
        ///   - updateVersion:   The version of the available update.
        ///   - notes:           The release's Markdown notes.
        ///   - downloadURL:     The direct download URL, or `nil` when the release
        ///                      has no downloadable asset.
        ///   - releaseURL:      The URL of the release page on GitHub.
        func show(
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

            window.center()

            self.window   = window
            self.retained = self

            NSApp.activate( ignoringOtherApps: true )
            window.makeKeyAndOrderFront( nil )
        }

        /// Closes the hosted window, which in turn releases the controller.
        private func close()
        {
            self.window?.close()
        }

        /// Releases the window and the controller's self-reference when the window closes.
        ///
        /// - Parameter notification: The `NSWindow.willCloseNotification` notification.
        func windowWillClose( _ notification: Notification )
        {
            self.window   = nil
            self.retained = nil
        }
    }

#endif
