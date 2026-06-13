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

import Cocoa

/// Checks a GitHub repository's releases and notifies the user when a newer
/// version of the running application is available.
///
/// The updater queries the repository's `releases` endpoint, compares the
/// newest published release against the running application's version (read
/// from its `Info.plist`), and presents an `NSAlert` describing the result.
/// `v`-prefixed tags are normalized before comparison, and drafts and
/// pre-releases are ignored.
public final class GitHubUpdater: Sendable
{
    /// The owner (user or organization) of the GitHub repository.
    public let owner:      String

    /// The name of the GitHub repository.
    public let repository: String

    /// The GitHub API URL of the repository's releases endpoint.
    public let url:        URL

    /// Creates an updater for the given GitHub repository.
    ///
    /// - Parameters:
    ///   - owner:      The owner (user or organization) of the repository.
    ///   - repository: The name of the repository.
    ///
    /// - Returns: `nil` if a valid releases URL cannot be built from the supplied values.
    public init?( owner: String, repository: String )
    {
        guard let url = URL( string: "https://api.github.com/repos/\( owner )/\( repository )/releases" )
        else
        {
            return nil
        }

        self.owner      = owner
        self.repository = repository
        self.url        = url
    }

    /// Checks for updates, reporting the outcome to the user.
    ///
    /// The check runs in a detached task. Alerts are shown for every outcome,
    /// including when the application is already up-to-date and when an error
    /// occurs.
    public func checkForUpdates()
    {
        Task.detached( priority: .userInitiated )
        {
            await self.checkForUpdates( showMessages: true )
        }
    }

    /// Checks for updates silently, only alerting the user when a newer version is available.
    ///
    /// The check runs in a low-priority detached task. No alert is shown when the
    /// application is already up-to-date or when an error occurs.
    public func checkForUpdatesInBackground()
    {
        Task.detached( priority: .background )
        {
            await self.checkForUpdates( showMessages: false )
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

    /// Normalizes a version string for comparison.
    ///
    /// Trims surrounding whitespace and removes a leading `v` or `V`, so that
    /// tags such as `"v1.2.3"` compare equal to bundle versions such as `"1.2.3"`.
    ///
    /// - Parameter version: The raw version string to normalize.
    ///
    /// - Returns: The normalized version string.
    private static func normalizedVersion( _ version: String ) -> String
    {
        let trimmed = version.trimmingCharacters( in: .whitespacesAndNewlines )

        if trimmed.first == "v" || trimmed.first == "V"
        {
            return String( trimmed.dropFirst() )
        }

        return trimmed
    }

    /// Returns whether one version string represents a newer version than another.
    ///
    /// Both values are normalized with ``normalizedVersion(_:)`` and compared
    /// numerically, so segments are ordered by value (for example `1.10` is newer
    /// than `1.9`).
    ///
    /// - Parameters:
    ///   - version: The version to test.
    ///   - other:   The version to compare against.
    ///
    /// - Returns: `true` if `version` is strictly newer than `other`, otherwise `false`.
    static func isVersion( _ version: String, newerThan other: String ) -> Bool
    {
        GitHubUpdater.normalizedVersion( version ).compare( GitHubUpdater.normalizedVersion( other ), options: .numeric ) == .orderedDescending
    }

    /// Parses the JSON payload of the GitHub releases endpoint.
    ///
    /// Decodes the array of releases, discards drafts, pre-releases, and entries
    /// missing a `tag_name` or `html_url`, and returns the remaining releases
    /// sorted newest-first.
    ///
    /// - Parameter data: The raw JSON data returned by the releases endpoint.
    ///
    /// - Returns: The parsed releases sorted from newest to oldest, or `nil` if the
    ///            data is not a JSON array of release objects.
    static func parseReleases( from data: Data ) -> [ ( version: String, url: String ) ]?
    {
        guard let releases = try? JSONSerialization.jsonObject( with: data ) as? [ [ String: Any ] ]
        else
        {
            return nil
        }

        return releases.compactMap
        {
            guard let version = $0[ "tag_name" ] as? String,
                  let url     = $0[ "html_url" ] as? String
            else
            {
                return nil
            }

            if $0[ "draft" ] as? Bool == true || $0[ "prerelease" ] as? Bool == true
            {
                return nil
            }

            return ( version: version, url: url )
        }
        .sorted
        {
            GitHubUpdater.isVersion( $0.version, newerThan: $1.version )
        }
    }

    /// Fetches the repository's releases and determines whether an update is available.
    ///
    /// Reads the running application's name and version from its `Info.plist`,
    /// fetches and parses the releases, and compares the newest published release
    /// against the current version. Depending on the outcome, an up-to-date or
    /// update-available alert is presented.
    ///
    /// - Parameter showMessages: When `true`, alerts are shown for every outcome,
    ///   including up-to-date and error states. When `false`, only an
    ///   update-available alert is shown and all other outcomes are silent.
    private func checkForUpdates( showMessages: Bool ) async
    {
        guard let current = Bundle.main.object( forInfoDictionaryKey: "CFBundleShortVersionString" ) as? String,
              let program = Bundle.main.object( forInfoDictionaryKey: "CFBundleName" ) as? String
        else
        {
            if showMessages
            {
                await self.showErrorAlert( message: "Unable to determine current version." )
            }

            return
        }

        let data:     Data
        let response: URLResponse

        do
        {
            ( data, response ) = try await URLSession.shared.data( from: self.url )
        }
        catch
        {
            if showMessages
            {
                await self.showErrorAlert( message: "Unable to fetch release information from GitHub: \( error.localizedDescription )" )
            }

            return
        }

        if let status = ( response as? HTTPURLResponse )?.statusCode, ( 200 ..< 300 ).contains( status ) == false
        {
            if showMessages
            {
                if status == 403 || status == 429
                {
                    await self.showErrorAlert( message: "GitHub rate limit reached. Please try again later." )
                }
                else
                {
                    await self.showErrorAlert( message: "Unable to fetch release information from GitHub (HTTP \( status ))." )
                }
            }

            return
        }

        guard let versions = GitHubUpdater.parseReleases( from: data )
        else
        {
            if showMessages
            {
                await self.showErrorAlert( message: "Unable to parse release information from GitHub." )
            }

            return
        }

        guard let latest = versions.first
        else
        {
            if showMessages
            {
                await self.showUpToDateAlert( application: program, version: current )
            }

            return
        }

        guard GitHubUpdater.isVersion( latest.version, newerThan: current )
        else
        {
            if showMessages
            {
                await self.showUpToDateAlert( application: program, version: current )
            }

            return
        }

        guard let url = URL( string: latest.url )
        else
        {
            if showMessages
            {
                await self.showErrorAlert( message: "Unable to parse release URL." )
            }

            return
        }

        if showMessages
        {
            await self.showUpdateAvailableAlert( application: program, version: current, update: latest.version, url: url )
        }
    }
}
