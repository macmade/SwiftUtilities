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

    public extension GitHubUpdater
    {
        /// Options controlling which update-check outcomes are reported to the user.
        ///
        /// Each option enables the modal alert for a single outcome of an update
        /// check, allowing callers to choose exactly which results are surfaced.
        struct MessageOptions: OptionSet, Sendable
        {
            public let rawValue: Int

            /// Creates a set of message options from a raw bitmask value.
            ///
            /// - Parameter rawValue: The raw bitmask value.
            public init( rawValue: Int )
            {
                self.rawValue = rawValue
            }

            /// Show an alert when the application is already up-to-date.
            public static let upToDate = MessageOptions( rawValue: 1 << 0 )

            /// Show an alert when a newer version is available.
            public static let updateAvailable = MessageOptions( rawValue: 1 << 1 )

            /// Show an alert when the update check fails.
            public static let error = MessageOptions( rawValue: 1 << 2 )

            /// Show an alert for every outcome.
            public static let all: MessageOptions = [ .upToDate, .updateAvailable, .error ]
        }

        /// How the update-available window should present a newer release.
        ///
        /// This is the value-level decision made by ``updateWindowMode(for:downloadURL:)``:
        /// given the caller's ``UpdateBehavior`` and whether the release has a
        /// downloadable asset, it selects the link window or the in-app update
        /// window, without performing any UI work. It is the test seam for the
        /// behavior-to-window routing.
        internal enum UpdateWindowMode: Equatable, Sendable
        {
            /// Present the link-based window, whose **Download** action opens the
            /// release in the browser.
            case link

            /// Present the in-app update window, which downloads, verifies, and
            /// installs the update in place.
            case inApp
        }

        /// The alert to present for an update-check outcome.
        ///
        /// This is the value-level decision made by ``present(_:messages:behavior:)``: given a
        /// result and the enabled ``MessageOptions``, it describes which alert (if any)
        /// to show, without performing any UI work. It is the test seam for the
        /// option-to-alert routing.
        internal enum Alert: Equatable, Sendable
        {
            /// No alert should be shown, because the outcome's option is disabled.
            case none

            /// Present the "up-to-date" alert.
            case upToDate( application: String, version: String )

            /// Present the "update available" alert.
            case updateAvailable( application: String, version: String, update: String, url: URL, notes: String, downloadURL: URL? )

            /// Present the error alert.
            case error( message: String )
        }

        /// Determines which alert to present for an update-check outcome.
        ///
        /// Pure: maps a result and the set of enabled message options to the alert
        /// that should be shown, returning ``Alert/none`` for outcomes the options
        /// suppress. Performs no UI work.
        ///
        /// - Parameters:
        ///   - result:   The outcome to present.
        ///   - messages: The set of outcomes for which an alert should be shown.
        ///
        /// - Returns: The alert to present, or ``Alert/none`` if the outcome is suppressed.
        internal static func alert( for result: UpdateCheckResult, messages: MessageOptions ) -> Alert
        {
            switch result
            {
                case .upToDate( let application, let version ):

                    return messages.contains( .upToDate ) ? .upToDate( application: application, version: version ) : .none

                case .updateAvailable( let application, let version, let update, let url, let notes, let downloadURL ):

                    return messages.contains( .updateAvailable ) ? .updateAvailable( application: application, version: version, update: update, url: url, notes: notes, downloadURL: downloadURL ) : .none

                case .failed( let reason ):

                    return messages.contains( .error ) ? .error( message: reason ) : .none
            }
        }

        /// Determines how the update-available window should present a newer release.
        ///
        /// Pure: maps the caller's ``UpdateBehavior`` and the release's downloadable
        /// asset to the ``UpdateWindowMode`` to use. In-app installation requires a
        /// downloadable asset in a supported ``UpdateArchiveFormat`` (`.zip` or
        /// `.dmg`), so ``UpdateBehavior/inApp`` falls back to
        /// ``UpdateWindowMode/link`` when there is no download URL or the asset is
        /// not a supported archive. ``UpdateBehavior/link`` always maps to
        /// ``UpdateWindowMode/link``. Performs no UI work.
        ///
        /// - Parameters:
        ///   - behavior:    The update-delivery behavior chosen by the caller.
        ///   - downloadURL: The release's direct download URL, or `nil` when the
        ///                  release has no downloadable asset.
        ///
        /// - Returns: The window mode to present.
        internal static func updateWindowMode( for behavior: UpdateBehavior, downloadURL: URL? ) -> UpdateWindowMode
        {
            guard behavior == .inApp,
                  let downloadURL,
                  UpdateArchiveFormat( url: downloadURL ) != nil
            else
            {
                return .link
            }

            return .inApp
        }

        /// Checks for updates, reporting the outcome to the user.
        ///
        /// The check runs in a detached task. Alerts are shown for every outcome,
        /// including when the application is already up-to-date and when an error
        /// occurs. An available update is delivered according to the updater's
        /// ``behavior``, configured at construction.
        func checkForUpdates()
        {
            Task.detached( priority: .userInitiated )
            {
                let result = await self.performUpdateCheck()

                await self.present( result, messages: .all )
            }
        }

        /// Checks for updates silently, only alerting the user when a newer version is available.
        ///
        /// The check runs in a low-priority detached task. No alert is shown when the
        /// application is already up-to-date or when an error occurs. An available
        /// update is delivered according to the updater's ``behavior``, configured
        /// at construction.
        func checkForUpdatesInBackground()
        {
            Task.detached( priority: .background )
            {
                let result = await self.performUpdateCheck()

                await self.present( result, messages: .updateAvailable )
            }
        }

        /// Presents an update-check result to the user.
        ///
        /// The up-to-date and error outcomes are shown as modal alerts; the
        /// update-available outcome opens the non-modal update window, whose flavor
        /// is chosen by ``updateWindowMode(for:downloadURL:)`` from the updater's
        /// ``behavior``.
        ///
        /// - Parameters:
        ///   - result:   The outcome to present.
        ///   - messages: The set of outcomes for which feedback should be shown.
        ///     Outcomes not present in the set are handled silently.
        @MainActor
        private func present( _ result: UpdateCheckResult, messages: MessageOptions )
        {
            switch GitHubUpdater.alert( for: result, messages: messages )
            {
                case .none:

                    break

                case .upToDate( let application, let version ):

                    self.showUpToDateAlert( application: application, version: version )

                case .updateAvailable( let application, let version, let update, let url, let notes, let downloadURL ):

                    switch GitHubUpdater.updateWindowMode( for: self.behavior, downloadURL: downloadURL )
                    {
                        case .link:

                            self.showUpdateAvailableWindow( application: application, version: version, update: update, url: url, notes: notes, downloadURL: downloadURL )

                        case .inApp:

                            self.showInAppUpdateWindow( application: application, version: version, update: update, url: url, notes: notes, downloadURL: downloadURL )
                    }

                case .error( let message ):

                    self.showErrorAlert( message: message )
            }
        }

        /// Presents a modal error alert.
        ///
        /// - Parameter message: The informative text describing the error.
        @MainActor
        private func showErrorAlert( message: String )
        {
            let alert             = NSAlert()
            alert.messageText     = Localization.string( "GitHubUpdater.alert.error.title" )
            alert.informativeText = message

            alert.runModal()
        }

        /// Presents a modal alert informing the user that the application is up-to-date.
        ///
        /// - Parameters:
        ///   - application: The display name of the application.
        ///   - version:     The current version of the application.
        @MainActor
        private func showUpToDateAlert( application: String, version: String )
        {
            let alert             = NSAlert()
            alert.messageText     = Localization.string( "GitHubUpdater.alert.upToDate.title" )
            alert.informativeText = String( format: Localization.string( "GitHubUpdater.alert.upToDate.message" ), application, version )

            alert.runModal()
        }

        /// Opens the non-modal window offering to download an available update.
        ///
        /// The window renders the release notes and offers Download (when an asset
        /// exists), View on GitHub, and Later. It is owned by a self-retaining
        /// ``UpdateWindowController`` so the `Sendable` updater needs no stored
        /// state.
        ///
        /// - Parameters:
        ///   - application: The display name of the application.
        ///   - version:     The current version of the application.
        ///   - update:      The version of the available update.
        ///   - url:         The URL of the release page on GitHub.
        ///   - notes:       The release's Markdown notes.
        ///   - downloadURL: The direct download URL of the release's first asset, or
        ///                  `nil` when the release has no downloadable asset.
        @MainActor
        private func showUpdateAvailableWindow( application: String, version: String, update: String, url: URL, notes: String, downloadURL: URL? )
        {
            UpdateWindowController.show(
                applicationName: application,
                currentVersion:  version,
                updateVersion:   update,
                notes:           notes,
                downloadURL:     downloadURL,
                releaseURL:      url
            )
        }

        /// Opens the window offering to download and install an available update in place.
        ///
        /// This is the entry point for the in-app update flow, selected when the
        /// caller opts into ``UpdateBehavior/inApp`` and the release has a
        /// downloadable asset.
        ///
        /// - Note: The in-app download and installation experience is delivered in a
        ///   later milestone. Until it lands, this presents the same link-based
        ///   window as ``showUpdateAvailableWindow(application:version:update:url:notes:downloadURL:)``
        ///   so an available update stays reachable.
        ///
        /// - Parameters:
        ///   - application: The display name of the application.
        ///   - version:     The current version of the application.
        ///   - update:      The version of the available update.
        ///   - url:         The URL of the release page on GitHub.
        ///   - notes:       The release's Markdown notes.
        ///   - downloadURL: The direct download URL of the release's first asset, or
        ///                  `nil` when the release has no downloadable asset.
        @MainActor
        private func showInAppUpdateWindow( application: String, version: String, update: String, url: URL, notes: String, downloadURL: URL? )
        {
            self.showUpdateAvailableWindow( application: application, version: version, update: update, url: url, notes: notes, downloadURL: downloadURL )
        }
    }

#endif
