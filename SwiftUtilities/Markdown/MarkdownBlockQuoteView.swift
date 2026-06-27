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

    /// Renders a Markdown block quote.
    ///
    /// The quote's nested blocks are rendered by recursing through
    /// ``MarkdownView``, indented behind a vertical accent bar.
    internal struct MarkdownBlockQuoteView: View
    {
        /// The quote's nested blocks.
        private let blocks: [ MarkdownBlock ]

        /// Creates a block-quote view.
        ///
        /// - Parameter blocks: The quote's nested blocks.
        init( blocks: [ MarkdownBlock ] )
        {
            self.blocks = blocks
        }

        /// The view's body.
        var body: some View
        {
            HStack( alignment: .top, spacing: 8 )
            {
                RoundedRectangle( cornerRadius: 1.5 )
                    .fill( Color.secondary.opacity( 0.5 ) )
                    .frame( width: 3 )

                MarkdownView( blocks: self.blocks )
            }
            .fixedSize( horizontal: false, vertical: true )
        }
    }

#endif
