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

    /// Renders a Markdown ordered or unordered list.
    ///
    /// Each item shows a leading marker — a number for ordered lists, a task-list
    /// checkbox for task items, or a bullet otherwise — beside its content, which
    /// is rendered by recursing through ``MarkdownView`` so nested lists and
    /// multi-paragraph items work naturally.
    internal struct MarkdownListView: View
    {
        /// The list's items.
        private let items: [ MarkdownListItem ]

        /// The starting number for an ordered list, or `nil` for a bulleted list.
        private let start: Int?

        /// Creates a list view.
        ///
        /// - Parameters:
        ///   - items: The list's items.
        ///   - start: The starting number for an ordered list, or `nil` for a
        ///            bulleted list.
        init( items: [ MarkdownListItem ], start: Int? )
        {
            self.items = items
            self.start = start
        }

        /// The view's body.
        var body: some View
        {
            VStack( alignment: .leading, spacing: 6 )
            {
                ForEach( Array( self.items.enumerated() ), id: \.offset )
                {
                    index, item in

                    HStack( alignment: .top, spacing: 6 )
                    {
                        Text( self.marker( for: item, index: index ) )
                            .font( item.checkbox == nil ? .body : .system( .body, design: .monospaced ) )
                            .monospacedDigit()

                        MarkdownView( blocks: item.blocks )
                    }
                }
            }
        }

        /// Builds the leading marker for a list item.
        ///
        /// - Parameters:
        ///   - item:  The list item.
        ///   - index: The item's index within the list.
        ///
        /// - Returns: A task-list checkbox glyph, a number, or a bullet.
        private func marker( for item: MarkdownListItem, index: Int ) -> String
        {
            switch item.checkbox
            {
                case .checked:   return "\u{2611}" // ☑
                case .unchecked: return "\u{2610}" // ☐
                case nil:        break
            }

            guard let start = self.start
            else
            {
                return "\u{2022}" // •
            }

            return "\( start + index )."
        }
    }

#endif
