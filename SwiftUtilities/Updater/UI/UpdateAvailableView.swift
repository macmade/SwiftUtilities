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

    import SwiftUI

    /// The content of the update-available window, for both update modes.
    ///
    /// Shows a header (the application name and a "current → new version" summary)
    /// and, in its idle state, the release notes rendered with ``MarkdownView`` and a
    /// trailing row of actions. **View on GitHub** and **Later** are always shown; the
    /// primary download action is shown only when a download URL exists.
    ///
    /// With no ``InAppUpdateViewModel`` it is the link window: the primary action is
    /// **Download**, handled by the caller (which opens the release in the browser).
    /// Given a model, it drives the in-app flow: the primary action becomes
    /// **Download & Install** and, once started, the notes are replaced in place by a
    /// progress bar and status text while the update downloads, installs, and
    /// relaunches — and by a readable error with a still-reachable release page on
    /// failure. This is the whole update UI; there is no separate in-app view.
    public struct UpdateAvailableView: View
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
        /// to decide whether the download action is shown and which action is the
        /// keyboard default.
        private let downloadURL: URL?

        #if !SWIFT_PACKAGE

        /// The in-app update view model, or `nil` for the link window.
        ///
        /// In-app updates require the Xcode framework, so this is absent from the
        /// SwiftPM build, where the view is always the link window.
        private let model: InAppUpdateViewModel?

        #endif

        /// Invoked when the user chooses to download the update (link mode only).
        private let onDownload: () -> Void

        /// Invoked when the user chooses to view the release on GitHub.
        private let onViewOnGitHub: () -> Void

        /// Invoked when the user dismisses the window.
        private let onLater: () -> Void

        #if !SWIFT_PACKAGE

        /// Creates the update-available content view.
        ///
        /// - Parameters:
        ///   - applicationName: The display name of the application.
        ///   - currentVersion:  The current version of the application.
        ///   - updateVersion:   The version of the available update.
        ///   - notes:           The release's Markdown notes.
        ///   - downloadURL:     The direct download URL, or `nil` when the release
        ///                      has no downloadable asset.
        ///   - model:           The in-app update view model, or `nil` for the link
        ///                      window.
        ///   - onDownload:      Invoked when the user chooses to download (link mode).
        ///   - onViewOnGitHub:  Invoked when the user chooses to view the release.
        ///   - onLater:         Invoked when the user dismisses the window.
        public init(
            applicationName: String,
            currentVersion:  String,
            updateVersion:   String,
            notes:           String,
            downloadURL:     URL?,
            model:           InAppUpdateViewModel? = nil,
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
            self.model           = model
            self.onDownload      = onDownload
            self.onViewOnGitHub  = onViewOnGitHub
            self.onLater         = onLater
        }

        #else

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
        public init(
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

        #endif

        /// The view's body.
        public var body: some View
        {
            VStack( alignment: .leading, spacing: 16 )
            {
                self.header

                #if !SWIFT_PACKAGE

                switch self.model?.state ?? .idle
                {
                    case .idle:

                        self.releaseNotes
                        self.actions

                    case .downloading( let fraction ):

                        self.progress( title: Localization.string( "GitHubUpdater.window.status.downloading" ), fraction: fraction )

                    case .installing:

                        self.progress( title: Localization.string( "GitHubUpdater.window.status.installing" ), fraction: nil )

                    case .relaunching:

                        self.progress( title: Localization.string( "GitHubUpdater.window.status.relaunching" ), fraction: nil )

                    case .failed( let message ):

                        self.failure( message: message )
                        self.actions
                }

                #else

                self.releaseNotes
                self.actions

                #endif
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

        #if !SWIFT_PACKAGE

        /// A titled progress bar filling the notes area; determinate when a fraction
        /// is known.
        ///
        /// - Parameters:
        ///   - title:    The status text shown above the bar.
        ///   - fraction: The fraction complete, or `nil` for an indeterminate bar.
        private func progress( title: String, fraction: Double? ) -> some View
        {
            VStack( spacing: 10 )
            {
                Text( title )
                    .font( .headline )

                if let fraction
                {
                    ProgressView( value: fraction )
                }
                else
                {
                    ProgressView()
                        .progressViewStyle( .linear )
                }
            }
            .frame( maxWidth: 320 )
            .frame( maxWidth: .infinity, maxHeight: .infinity )
        }

        /// The failure message with a warning icon, filling the notes area.
        ///
        /// - Parameter message: The readable failure message.
        private func failure( message: String ) -> some View
        {
            VStack( spacing: 12 )
            {
                Image( systemName: "exclamationmark.triangle.fill" )
                    .font( .system( size: 40 ) )
                    .foregroundStyle( .yellow )

                Text( Localization.string( "GitHubUpdater.window.error.title" ) )
                    .font( .headline )

                Text( message )
                    .foregroundStyle( .secondary )
                    .multilineTextAlignment( .center )
            }
            .frame( maxWidth: 360 )
            .frame( maxWidth: .infinity, maxHeight: .infinity )
        }

        #endif

        /// The trailing row of actions, shown while idle and on failure.
        ///
        /// Later sits on the leading edge; View on GitHub and the download action
        /// (when applicable) sit on the trailing edge. The default button is the
        /// download action when it is shown, otherwise View on GitHub.
        private var actions: some View
        {
            HStack
            {
                Button( Localization.string( "GitHubUpdater.window.button.later" ), action: self.onLater )

                Spacer()

                Button( Localization.string( "GitHubUpdater.window.button.view" ), action: self.onViewOnGitHub )
                    .keyboardShortcut( self.showsDownload ? nil : KeyboardShortcut.defaultAction )

                self.downloadButton
            }
        }

        /// The download / install action, shown only in the idle state with an asset.
        ///
        /// Its label and behavior follow the mode: **Download & Install** starting the
        /// in-app flow when a model is present, or **Download** invoking the link
        /// callback otherwise.
        @ViewBuilder
        private var downloadButton: some View
        {
            if self.showsDownload
            {
                #if !SWIFT_PACKAGE

                if let model = self.model
                {
                    Button( Localization.string( "GitHubUpdater.window.button.install" ) )
                    {
                        Task { await model.start() }
                    }
                    .keyboardShortcut( .defaultAction )
                }
                else
                {
                    Button( Localization.string( "GitHubUpdater.window.button.download" ), action: self.onDownload )
                        .keyboardShortcut( .defaultAction )
                }

                #else

                Button( Localization.string( "GitHubUpdater.window.button.download" ), action: self.onDownload )
                    .keyboardShortcut( .defaultAction )

                #endif
            }
        }

        /// Whether the download action is shown: only while idle and with an asset.
        private var showsDownload: Bool
        {
            #if !SWIFT_PACKAGE

            if case .idle = self.model?.state ?? .idle, self.downloadURL != nil
            {
                return true
            }

            return false

            #else

            return self.downloadURL != nil

            #endif
        }
    }

    #if !SWIFT_PACKAGE

    /// A downloader that does nothing, for previews.
    private struct PreviewDownloader: UpdateDownloading
    {
        func download( from url: URL, into directory: URL, progress: @Sendable ( DownloadProgress ) -> Void ) async throws -> URL
        {
            url
        }
    }

    /// An installer that does nothing, for previews.
    private struct PreviewInstaller: UpdateInstaller
    {
        func install( archive: URL, format: UpdateArchiveFormat, replacing target: URL, into workingDirectory: URL, progress: @escaping @Sendable ( InstallProgress ) -> Void ) async throws
        {}
    }

    /// Builds an in-app view model fixed to a state, for previews.
    ///
    /// - Parameter state: The state to show.
    ///
    /// - Returns: A preview view model.
    @MainActor
    private func previewModel( state: InAppUpdateViewModel.State ) -> InAppUpdateViewModel
    {
        InAppUpdateViewModel(
            downloader:  PreviewDownloader(),
            installer:   PreviewInstaller(),
            downloadURL: URL( fileURLWithPath: "/tmp/App.zip" ),
            format:      .zip,
            target:      URL( fileURLWithPath: "/Applications/App.app" ),
            terminate:   {},
            state:       state
        )
    }

    #endif

    private let previewNotes =
    """
    ## What's New

    - A shiny new feature
    - A handful of bug fixes
    """

    #Preview( "Link" )
    {
        UpdateAvailableView(
            applicationName: "Application",
            currentVersion:  "1.0.0",
            updateVersion:   "1.1.0",
            notes:           previewNotes,
            downloadURL:     URL( string: "https://example.com/download" ),
            onDownload:      {},
            onViewOnGitHub:  {},
            onLater:         {}
        )
    }

    #if !SWIFT_PACKAGE

    #Preview( "In-App" )
    {
        UpdateAvailableView(
            applicationName: "Application",
            currentVersion:  "1.0.0",
            updateVersion:   "1.1.0",
            notes:           previewNotes,
            downloadURL:     URL( string: "https://example.com/app.zip" ),
            model:           previewModel( state: .idle ),
            onDownload:      {},
            onViewOnGitHub:  {},
            onLater:         {}
        )
    }

    #Preview( "Downloading" )
    {
        UpdateAvailableView(
            applicationName: "Application",
            currentVersion:  "1.0.0",
            updateVersion:   "1.1.0",
            notes:           previewNotes,
            downloadURL:     URL( string: "https://example.com/app.zip" ),
            model:           previewModel( state: .downloading( fraction: 0.4 ) ),
            onDownload:      {},
            onViewOnGitHub:  {},
            onLater:         {}
        )
    }

    #Preview( "Failed" )
    {
        UpdateAvailableView(
            applicationName: "Application",
            currentVersion:  "1.0.0",
            updateVersion:   "1.1.0",
            notes:           previewNotes,
            downloadURL:     URL( string: "https://example.com/app.zip" ),
            model:           previewModel( state: .failed( message: "The downloaded application is not signed by the same developer." ) ),
            onDownload:      {},
            onViewOnGitHub:  {},
            onLater:         {}
        )
    }

    #endif

#endif
