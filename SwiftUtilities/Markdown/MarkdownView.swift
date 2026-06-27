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

    /// Renders Markdown as native SwiftUI views.
    ///
    /// The Markdown is parsed into the presentation-agnostic ``MarkdownBlock``
    /// model (see ``MarkdownContent/parse(_:)``), then laid out as a
    /// leading-aligned vertical stack. Each block is rendered by a dedicated
    /// view, and nested content (list items, block quotes) is rendered by
    /// recursing through this view. Links open in the default browser.
    public struct MarkdownView: View
    {
        /// The blocks to render.
        private let blocks: [ MarkdownBlock ]

        /// Creates a view that renders the given Markdown string.
        ///
        /// - Parameter markdown: The Markdown source to render.
        public init( _ markdown: String )
        {
            self.blocks = MarkdownContent.parse( markdown )
        }

        /// Creates a view that renders an already-parsed block model.
        ///
        /// Used both for the top-level document and, recursively, for the nested
        /// blocks of list items and block quotes.
        ///
        /// - Parameter blocks: The blocks to render.
        public init( blocks: [ MarkdownBlock ] )
        {
            self.blocks = blocks
        }

        /// The view's body: the blocks laid out vertically.
        public var body: some View
        {
            VStack( alignment: .leading, spacing: 10 )
            {
                ForEach( Array( self.blocks.enumerated() ), id: \.offset )
                {
                    _, block in

                    self.view( for: block )
                }
            }
        }

        /// Selects the dedicated view for a block.
        ///
        /// - Parameter block: The block to render.
        ///
        /// - Returns: The view for the block.
        @ViewBuilder
        private func view( for block: MarkdownBlock ) -> some View
        {
            switch block
            {
                case .heading( let level, let inlines ):

                    MarkdownHeadingView( level: level, inlines: inlines )

                case .paragraph( let inlines ):

                    MarkdownParagraphView( inlines: inlines )

                case .unorderedList( let items ):

                    MarkdownListView( items: items, start: nil )

                case .orderedList( let start, let items ):

                    MarkdownListView( items: items, start: start )

                case .blockQuote( let blocks ):

                    MarkdownBlockQuoteView( blocks: blocks )

                case .codeBlock( _, let code ):

                    MarkdownCodeBlockView( code: code )

                case .thematicBreak:

                    MarkdownThematicBreakView()
            }
        }
    }

    #Preview
    {
        MarkdownView(
            """
            # Heading

            A paragraph with **bold**, *italic*, and `inline code`.

            - First item
            - Second item

            > A block quote.

            ---

            ```swift
            let answer = 42
            ```
            """
        )
        .padding()
        .frame( width: 400 )
    }

#endif
