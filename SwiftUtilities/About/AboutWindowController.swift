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

    /// Hosts the custom About window.
    ///
    /// A thin ``HostingWindowController`` subclass: it builds the About window's
    /// content and chrome and inherits the single-window lifetime management.
    @MainActor
    public final class AboutWindowController: HostingWindowController
    {
        /// Shows the About window for the running application, reusing the existing one if open.
        ///
        /// The application's name, version, and copyright are read from the
        /// bundle's `Info.plist` (see ``title``, ``version``, and ``copyright``),
        /// and the icon defaults to the application's icon. This is the convenient
        /// path; use ``show(applicationName:version:copyright:icon:)`` to supply
        /// the values explicitly.
        ///
        /// - Parameters:
        ///   - bundle: The bundle to read the application information from.
        ///             Defaults to the main bundle.
        ///   - icon:   The icon to display. Defaults to the application's icon.
        public static func show( bundle: Bundle = .main, icon: NSImage = NSApp.applicationIconImage )
        {
            AboutWindowController.show(
                applicationName: bundle.title,
                version:         bundle.version,
                copyright:       bundle.copyright,
                icon:            icon
            )
        }

        /// Shows the About window, reusing the existing one if open.
        ///
        /// - Parameters:
        ///   - applicationName: The application's display name.
        ///   - version:         The application's version string.
        ///   - copyright:       The application's human-readable copyright string.
        ///   - icon:            The application's icon.
        public static func show( applicationName: String, version: String, copyright: String, icon: NSImage )
        {
            HostingWindowController.show( using: AboutWindowController.init )
            {
                $0.present(
                    rootView: AboutView( applicationName: applicationName, version: version, copyright: copyright, icon: icon ).padding(),
                    sizing:   .fitContent
                )
                {
                    window in

                    window.title                      = String( format: Localization.string( "About.window.title" ), applicationName )
                    window.titleVisibility            = .hidden
                    window.titlebarAppearsTransparent = true

                    window.styleMask.remove( .resizable )
                    window.styleMask.insert( .fullSizeContentView )
                }
            }
        }
    }

#endif
