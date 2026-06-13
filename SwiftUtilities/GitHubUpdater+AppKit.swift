/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2025, Jean-David Gadina - www.xs-labs.com
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
    /// Checks for updates, reporting the outcome to the user.
    ///
    /// The check runs in a detached task. Alerts are shown for every outcome,
    /// including when the application is already up-to-date and when an error
    /// occurs.
    func checkForUpdates()
    {
        Task.detached( priority: .userInitiated )
        {
            let result = await self.performUpdateCheck()

            await self.present( result, showMessages: true )
        }
    }

    /// Checks for updates silently, only alerting the user when a newer version is available.
    ///
    /// The check runs in a low-priority detached task. No alert is shown when the
    /// application is already up-to-date or when an error occurs.
    func checkForUpdatesInBackground()
    {
        Task.detached( priority: .background )
        {
            let result = await self.performUpdateCheck()

            await self.present( result, showMessages: false )
        }
    }

    /// Presents an update-check result to the user as a modal alert.
    ///
    /// - Parameters:
    ///   - result:       The outcome to present.
    ///   - showMessages: When `true`, an alert is shown for every outcome. When
    ///     `false`, all outcomes are silent.
    @MainActor
    private func present( _ result: UpdateCheckResult, showMessages: Bool )
    {
        switch result
        {
            case .upToDate( let application, let version ):

                if showMessages
                {
                    self.showUpToDateAlert( application: application, version: version )
                }

            case .updateAvailable( let application, let version, let update, let url ):

                if showMessages
                {
                    self.showUpdateAvailableAlert( application: application, version: version, update: update, url: url )
                }

            case .failed( let reason ):

                if showMessages
                {
                    self.showErrorAlert( message: reason )
                }
        }
    }

    /// Presents a modal error alert.
    ///
    /// - Parameter message: The informative text describing the error.
    @MainActor
    private func showErrorAlert( message: String )
    {
        let alert             = NSAlert()
        alert.messageText     = "Error"
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
        alert.messageText     = "You're up-to-date!"
        alert.informativeText = "\( application ) \( version ) is currently the newest available version."

        alert.runModal()
    }

    /// Presents a modal alert offering to download an available update.
    ///
    /// If the user chooses to download, the release page is opened in the default browser.
    ///
    /// - Parameters:
    ///   - application: The display name of the application.
    ///   - version:     The current version of the application.
    ///   - update:      The version of the available update.
    ///   - url:         The URL of the release page to open if the user accepts.
    @MainActor
    private func showUpdateAvailableAlert( application: String, version: String, update: String, url: URL )
    {
        let alert             = NSAlert()
        alert.messageText     = "Update Available"
        alert.informativeText = "\( application ) \( update ) is available.\nYou are currently on version \( version ).\n\nWould you like to download the new version?"

        alert.addButton( withTitle: "View and Download" )
        alert.addButton( withTitle: "Later" )

        if alert.runModal() == .alertFirstButtonReturn
        {
            NSWorkspace.shared.open( url )
        }
    }
}

#endif
