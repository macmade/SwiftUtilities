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

#if canImport( SwiftUI )

    import SwiftUI

    /// The content of the update-available window.
    ///
    /// Shows a header (the application name and a "current → new version"
    /// summary), the release notes rendered with ``MarkdownView`` inside a
    /// scroll view with its own distinct background, and a trailing row of
    /// actions. The actions are delivered as callbacks so the hosting controller
    /// owns the actual behavior; the **Download** action is shown only when a
    /// download URL exists, while **View on GitHub** and **Later** are always
    /// shown.
    internal struct UpdateAvailableView: View
    {
        /// The display name of the application.
        private let applicationName: String

        /// The current version of the application.
        private let currentVersion: String

        /// The version of the available update.
        private let updateVersion: String

        /// The release's Markdown notes.
        private let notes: String

        /// The direct download URL, or `nil` when the release has no asset. Used
        /// to decide whether the Download action is shown and which action is the
        /// keyboard default.
        private let downloadURL: URL?

        /// Invoked when the user chooses to download the update.
        private let onDownload: () -> Void

        /// Invoked when the user chooses to view the release on GitHub.
        private let onViewOnGitHub: () -> Void

        /// Invoked when the user dismisses the window without downloading.
        private let onLater: () -> Void

        /// Creates the update-available content view.
        ///
        /// - Parameters:
        ///   - applicationName: The display name of the application.
        ///   - currentVersion:  The current version of the application.
        ///   - updateVersion:   The version of the available update.
        ///   - notes:           The release's Markdown notes.
        ///   - downloadURL:     The direct download URL, or `nil` when the release
        ///                      has no downloadable asset.
        ///   - onDownload:      Invoked when the user chooses to download.
        ///   - onViewOnGitHub:  Invoked when the user chooses to view the release.
        ///   - onLater:         Invoked when the user dismisses the window.
        init(
            applicationName: String,
            currentVersion:  String,
            updateVersion:   String,
            notes:           String,
            downloadURL:     URL?,
            onDownload:      @escaping () -> Void,
            onViewOnGitHub:  @escaping () -> Void,
            onLater:         @escaping () -> Void
        )
        {
            self.applicationName = applicationName
            self.currentVersion  = currentVersion
            self.updateVersion   = updateVersion
            self.notes           = notes
            self.downloadURL     = downloadURL
            self.onDownload      = onDownload
            self.onViewOnGitHub  = onViewOnGitHub
            self.onLater         = onLater
        }

        /// The view's body.
        var body: some View
        {
            VStack( alignment: .leading, spacing: 16 )
            {
                self.header

                self.releaseNotes

                self.buttons
            }
            .padding( 20 )
            .frame( minWidth: 480, minHeight: 360 )
        }

        /// The header showing the application name and version summary.
        private var header: some View
        {
            VStack( alignment: .leading, spacing: 4 )
            {
                Text( String( format: Localization.string( "GitHubUpdater.window.heading" ), self.applicationName, self.updateVersion ) )
                    .font( .title2 )
                    .bold()

                Text( String( format: Localization.string( "GitHubUpdater.window.subtitle" ), self.currentVersion ) )
                    .foregroundStyle( .secondary )
            }
        }

        /// The scrollable release notes, on a distinct text-area background.
        private var releaseNotes: some View
        {
            ScrollView
            {
                MarkdownView( self.notes )
                    .frame( maxWidth: .infinity, alignment: .leading )
                    .padding( 12 )
            }
            .background( Color.primary.opacity( 0.05 ), in: RoundedRectangle( cornerRadius: 8 ) )
            .overlay( RoundedRectangle( cornerRadius: 8 ).stroke( Color.primary.opacity( 0.12 ) ) )
        }

        /// The trailing row of action buttons.
        ///
        /// Later sits on the leading edge; View on GitHub and Download (when a
        /// download URL exists) sit on the trailing edge. The default button is
        /// Download when an asset exists, otherwise View on GitHub.
        private var buttons: some View
        {
            HStack
            {
                Button( Localization.string( "GitHubUpdater.window.button.later" ), action: self.onLater )

                Spacer()

                Button( Localization.string( "GitHubUpdater.window.button.view" ), action: self.onViewOnGitHub )
                    .keyboardShortcut( self.downloadURL == nil ? KeyboardShortcut.defaultAction : nil )

                if self.downloadURL != nil
                {
                    Button( Localization.string( "GitHubUpdater.window.button.download" ), action: self.onDownload )
                        .keyboardShortcut( .defaultAction )
                }
            }
        }
    }

#endif
