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

public final class GitHubUpdater: Sendable
{
    public let owner:      String
    public let repository: String
    public let url:        URL

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

    @MainActor
    public func checkForUpdates()
    {
        Task.detached( priority: .userInitiated )
        {
            await self.checkForUpdates( showMessages: true )
        }
    }

    @MainActor
    public func checkForUpdatesInBackground()
    {
        Task.detached( priority: .background )
        {
            await self.checkForUpdates( showMessages: false )
        }
    }

    private func showErrorAlert( message: String )
    {
        Task
        {
            @MainActor in

            let alert             = NSAlert()
            alert.messageText     = "Error"
            alert.informativeText = message

            alert.runModal()
        }
    }

    private func showUpToDateAlert( application: String, version: String )
    {
        Task
        {
            @MainActor in

            let alert             = NSAlert()
            alert.messageText     = "You're up-to-date!"
            alert.informativeText = "\( application ) \( version ) is currently the newest available version."

            alert.runModal()
        }
    }

    private func showUpdateAvailableAlert( application: String, version: String, update: String, url: URL )
    {
        Task
        {
            @MainActor in

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

    private func checkForUpdates( showMessages: Bool ) async
    {
        guard let current = Bundle.main.object( forInfoDictionaryKey: "CFBundleShortVersionString" ) as? String,
              let program = Bundle.main.object( forInfoDictionaryKey: "CFBundleName" ) as? String
        else
        {
            if showMessages
            {
                self.showErrorAlert( message: "Unable to determine current version." )
            }

            return
        }

        guard let ( data, _ ) = try? await URLSession.shared.data( from: self.url )
        else
        {
            if showMessages
            {
                self.showErrorAlert( message: "Unable to fetch release information from GitHub." )
            }

            return
        }

        guard let releases = try? JSONSerialization.jsonObject( with: data ) as? [ [ String: Any ] ]
        else
        {
            if showMessages
            {
                self.showErrorAlert( message: "Unable to parse release information from GitHub." )
            }

            return
        }

        let versions: [ ( version: String, url: String ) ] = releases.compactMap
        {
            guard let version = $0[ "tag_name" ] as? String,
                  let url     = $0[ "html_url" ] as? String
            else
            {
                return nil
            }

            return ( version: version, url: url )
        }
        .sorted
        {
            $0.version.compare( $1.version, options: .numeric ) == .orderedDescending
        }

        guard let latest = versions.first
        else
        {
            if showMessages
            {
                self.showUpToDateAlert( application: program, version: current )
            }

            return
        }

        guard current.compare( latest.version, options: .numeric ) == .orderedAscending
        else
        {
            if showMessages
            {
                self.showUpToDateAlert( application: program, version: current )
            }

            return
        }

        guard let url = URL( string: latest.url )
        else
        {
            if showMessages
            {
                self.showErrorAlert( message: "Unable to parse release URL." )
            }

            return
        }

        if showMessages
        {
            self.showUpdateAvailableAlert( application: program, version: current, update: latest.version, url: url )
        }
    }
}
