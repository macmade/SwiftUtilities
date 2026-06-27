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

    /// Hosts the update-available window.
    ///
    /// A thin ``HostingWindowController`` subclass: it builds the update window's
    /// content and chrome and inherits the single-window lifetime management.
    ///
    /// ``GitHubUpdater`` is a `Sendable` value type with no mutable state, so it
    /// cannot itself retain a window. Instead it calls the type method
    /// ``show(applicationName:currentVersion:updateVersion:notes:downloadURL:releaseURL:)``,
    /// which guarantees a single update window.
    @MainActor
    internal final class UpdateWindowController: HostingWindowController
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
        static func show(
            applicationName: String,
            currentVersion:  String,
            updateVersion:   String,
            notes:           String,
            downloadURL:     URL?,
            releaseURL:      URL
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
                    }
                )

                controller.present( rootView: view, sizing: .fixed( UpdateWindowController.contentSize ) )
                {
                    window in

                    window.title = Localization.string( "GitHubUpdater.window.title" )
                }
            }
        }
    }

#endif
