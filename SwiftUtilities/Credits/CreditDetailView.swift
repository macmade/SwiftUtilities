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

    /// The detail pane presenting a single ``Credit``.
    ///
    /// Shows the project's name as a title with a trailing license ``Pill``, a
    /// separator, then the author, description, and — when present — a link to
    /// the project's website, followed by the full license text in a scrollable
    /// area with its own distinct background. The view is purely presentational:
    /// it renders the ``Credit`` it is given and carries no behavior of its own.
    public struct CreditDetailView: View
    {
        /// The credit to present.
        private let credit: Credit

        /// Creates a detail view presenting the given credit.
        ///
        /// - Parameter credit: The credit to present.
        public init( _ credit: Credit )
        {
            self.credit = credit
        }

        /// The view's content.
        public var body: some View
        {
            VStack( alignment: .leading, spacing: 16 )
            {
                self.header

                Divider()

                self.information

                self.license
            }
            .padding( 20 )
            .frame( maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading )
        }

        /// The header: the project name as a title with a trailing license pill
        /// (vertically centered on the title), and the author below the title.
        private var header: some View
        {
            VStack( alignment: .leading, spacing: 4 )
            {
                HStack
                {
                    Text( self.credit.name )
                        .font( .title2 )
                        .bold()

                    Spacer()

                    Pill( self.credit.licenseName )
                }

                Text( self.credit.author )
                    .foregroundStyle( .secondary )
            }
        }

        /// The project description and an optional website link.
        private var information: some View
        {
            VStack( alignment: .leading, spacing: 8 )
            {
                Text( self.credit.description )

                self.website
            }
        }

        /// A link to the project's website, with a leading right-facing arrow icon,
        /// shown only when a URL is present.
        @ViewBuilder
        private var website: some View
        {
            if let url = self.credit.website
            {
                Link( destination: url )
                {
                    Label( url.absoluteString, systemImage: "arrow.right" )
                }
            }
        }

        /// The full license text, selectable, in a scrollable area with a distinct
        /// background and a rounded border.
        private var license: some View
        {
            ScrollView
            {
                Text( self.credit.licenseText )
                    .font( .system( .callout, design: .monospaced ) )
                    .textSelection( .enabled )
                    .frame( maxWidth: .infinity, alignment: .leading )
                    .padding( 12 )
            }
            .background( Color.primary.opacity( 0.05 ), in: RoundedRectangle( cornerRadius: 8 ) )
            .overlay( RoundedRectangle( cornerRadius: 8 ).stroke( Color.primary.opacity( 0.12 ) ) )
        }
    }

    #Preview( "With website" )
    {
        CreditDetailView(
            Credit(
                name:        "SwiftUtilities",
                author:      "Jean-David Gadina",
                description: "A collection of reusable Swift utilities for macOS applications.",
                website:     URL( string: "https://github.com/macmade/SwiftUtilities" ),
                licenseName: "MIT",
                licenseText:
                """
                The MIT License (MIT)

                Copyright (c) 2026, Jean-David Gadina - www.xs-labs.com

                Permission is hereby granted, free of charge, to any person
                obtaining a copy of this software …
                """
            )
        )
        .frame( width: 480, height: 360 )
    }

    #Preview( "Without website" )
    {
        CreditDetailView(
            Credit(
                name:        "Example",
                author:      "Jane Doe",
                description: "A sample project with no website.",
                website:     nil,
                licenseName: "Apache-2.0",
                licenseText: "Apache License, Version 2.0 …"
            )
        )
        .frame( width: 480, height: 360 )
    }

#endif
