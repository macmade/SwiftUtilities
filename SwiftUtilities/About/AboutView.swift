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

    /// The contents of a generic About window: the application icon beside its
    /// name, version and copyright.
    ///
    /// The view is purely presentational: the caller supplies the values to
    /// display, so the component carries no dependency on any particular bundle
    /// and can be reused across applications.
    public struct AboutView: View
    {
        /// The application's display name.
        private let applicationName: String

        /// The application's version string.
        private let version: String

        /// The application's human-readable copyright string.
        private let copyright: String

        /// The application's icon.
        private let icon: NSImage

        /// Creates an About view for the given application metadata.
        ///
        /// - Parameters:
        ///   - applicationName: The application's display name.
        ///   - version:         The application's version string.
        ///   - copyright:       The application's human-readable copyright string.
        ///   - icon:            The application's icon.
        public init( applicationName: String, version: String, copyright: String, icon: NSImage )
        {
            self.applicationName = applicationName
            self.version         = version
            self.copyright       = copyright
            self.icon            = icon
        }

        /// The view's content.
        public var body: some View
        {
            HStack
            {
                Image( nsImage: self.icon )
                    .resizable()
                    .frame( width: 200, height: 200 )

                VStack( alignment: .leading )
                {
                    Spacer()

                    Text( self.applicationName )
                        .font( .largeTitle )

                    Text( self.version )
                        .font( .title3 )
                        .foregroundStyle( .secondary )

                    Spacer()

                    Text( self.copyright )
                        .foregroundStyle( .secondary )

                    Spacer()
                }
                .padding( .trailing )
            }
            .frame( maxHeight: 200 )
        }
    }

    #Preview
    {
        AboutView(
            applicationName: "Application",
            version:         "1.0.0 (42)",
            copyright:       "Copyright © 2026, Example",
            icon:            NSImage( named: NSImage.applicationIconName ) ?? NSImage()
        )
        .padding()
    }

#endif
