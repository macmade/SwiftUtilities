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

    /// The full content of the Credits window.
    ///
    /// A two-pane `NavigationSplitView`: the sidebar lists every credited project
    /// alphabetically by name (case-insensitively) as a ``CreditRow``, and the
    /// detail pane shows a ``CreditDetailView`` for the current selection. The
    /// first project is selected by default; a placeholder is shown when the list
    /// is empty or nothing is selected. The consumer passes the credits in any
    /// order — the view is responsible for sorting them.
    public struct CreditsView: View
    {
        /// The credits to display, pre-sorted alphabetically by name.
        private let credits: [ Credit ]

        /// The currently selected credit, or `nil` when nothing is selected.
        @State private var selection: Credit?

        /// Creates the Credits window content for the given credits.
        ///
        /// The credits may be passed in any order; they are sorted alphabetically
        /// by name (case-insensitively) for display, and the first is selected by
        /// default.
        ///
        /// - Parameter credits: The projects to credit.
        public init( _ credits: [ Credit ] )
        {
            let sorted = credits.sorted
            {
                $0.name.localizedCaseInsensitiveCompare( $1.name ) == .orderedAscending
            }

            self.credits    = sorted
            self._selection = State( initialValue: sorted.first )
        }

        /// The view's content.
        public var body: some View
        {
            NavigationSplitView
            {
                List( selection: self.$selection )
                {
                    ForEach( self.credits )
                    {
                        credit in

                        CreditRow( credit ).tag( credit )
                    }
                }
                .navigationSplitViewColumnWidth( min: 250, ideal: 250 )
            }
            detail:
            {
                self.detail
            }
        }

        /// The detail pane: the selected credit's detail view, or the placeholder.
        @ViewBuilder
        private var detail: some View
        {
            if let selection = self.selection
            {
                CreditDetailView( selection )
            }
            else
            {
                self.placeholder
            }
        }

        /// The placeholder shown when the list is empty or nothing is selected: an
        /// icon above a message explaining that the application uses the listed
        /// projects.
        private var placeholder: some View
        {
            VStack( spacing: 12 )
            {
                Image( systemName: "heart" )
                    .font( .largeTitle )
                    .foregroundStyle( .secondary )

                Text( Localization.string( "Credits.placeholder" ) )
                    .font( .title3 )
                    .foregroundStyle( .secondary )
                    .multilineTextAlignment( .center )
            }
            .padding()
            .frame( maxWidth: .infinity, maxHeight: .infinity )
        }
    }

    #Preview
    {
        CreditsView(
            [
                Credit(
                    name:        "SwiftUtilities",
                    author:      "Jean-David Gadina",
                    description: "A collection of reusable Swift utilities for macOS applications.",
                    website:     URL( string: "https://github.com/macmade/SwiftUtilities" ),
                    licenseName: "MIT",
                    licenseText: "The MIT License (MIT) …"
                ),
                Credit(
                    name:        "Example",
                    author:      "Jane Doe",
                    description: "A sample project with no website.",
                    website:     nil,
                    licenseName: "Apache-2.0",
                    licenseText: "Apache License, Version 2.0 …"
                ),
                Credit(
                    name:        "Another Library",
                    author:      "John Appleseed",
                    description: "Yet another dependency.",
                    website:     URL( string: "https://example.com" ),
                    licenseName: "BSD-3-Clause",
                    licenseText: "BSD 3-Clause License …"
                ),
            ]
        )
        .frame( width: 720, height: 480 )
    }

#endif
