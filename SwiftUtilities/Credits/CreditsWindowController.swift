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

    /// Hosts the Credits window.
    ///
    /// A thin ``HostingWindowController`` subclass: it builds the Credits window's
    /// content and chrome and inherits the single-window lifetime management. Unlike
    /// the fixed-size About window, the Credits window is resizable, opening at a
    /// sensible initial size with a minimum content size and a standard titlebar.
    @MainActor
    public final class CreditsWindowController: HostingWindowController
    {
        /// The window's initial content size.
        private static let initialSize = NSSize( width: 720, height: 480 )

        /// The window's minimum content size.
        private static let minimumSize = NSSize( width: 600, height: 360 )

        /// Shows the Credits window, reusing the existing one if open.
        ///
        /// The window lists the given credits in its sidebar and shows the selected
        /// project's details; a second call brings the existing window to the front
        /// rather than opening another, and the window releases itself on close.
        ///
        /// - Parameter credits: The projects to credit.
        public static func show( credits: [ Credit ] )
        {
            HostingWindowController.show( using: CreditsWindowController.init )
            {
                $0.present(
                    rootView: CreditsView( credits ),
                    sizing:   .fixed( CreditsWindowController.initialSize )
                )
                {
                    window in

                    window.title          = Localization.string( "Credits.window.title" )
                    window.contentMinSize = CreditsWindowController.minimumSize
                }
            }
        }
    }

#endif
