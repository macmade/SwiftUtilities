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

    /// A single row in the Credits window's sidebar.
    ///
    /// Presents one credited project: its name with the author below in a
    /// secondary style, and the license name as a trailing ``Pill`` vertically
    /// centered on the row. The view is purely presentational.
    public struct CreditRow: View
    {
        /// The credit presented by the row.
        private let credit: Credit

        /// Creates a sidebar row presenting the given credit.
        ///
        /// - Parameter credit: The credit to present.
        public init( _ credit: Credit )
        {
            self.credit = credit
        }

        /// The view's content.
        public var body: some View
        {
            HStack( spacing: 8 )
            {
                VStack( alignment: .leading, spacing: 2 )
                {
                    Text( self.credit.name )

                    Text( self.credit.author )
                        .font( .caption )
                        .foregroundStyle( .secondary )
                }

                Spacer()

                Pill( self.credit.licenseName )
            }
            .padding( .vertical, 2 )
        }
    }

    #Preview
    {
        List
        {
            CreditRow(
                Credit(
                    name:        "SwiftUtilities",
                    author:      "Jean-David Gadina",
                    description: "A collection of reusable Swift utilities.",
                    website:     URL( string: "https://github.com/macmade/SwiftUtilities" ),
                    licenseName: "MIT",
                    licenseText: "The MIT License (MIT) …"
                )
            )

            CreditRow(
                Credit(
                    name:        "Example",
                    author:      "Jane Doe",
                    description: "A sample project.",
                    website:     nil,
                    licenseName: "Apache-2.0",
                    licenseText: "Apache License, Version 2.0 …"
                )
            )
        }
        .frame( width: 280 )
    }

#endif
