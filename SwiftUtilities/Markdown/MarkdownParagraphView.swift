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

    /// Renders a Markdown paragraph.
    ///
    /// The paragraph's inline content is rendered with ``MarkdownInlineRenderer``
    /// and allowed to wrap across as many lines as needed.
    public struct MarkdownParagraphView: View
    {
        /// The paragraph's inline content.
        private let inlines: [ MarkdownInline ]

        /// Creates a paragraph view.
        ///
        /// - Parameter inlines: The paragraph's inline content.
        public init( inlines: [ MarkdownInline ] )
        {
            self.inlines = inlines
        }

        /// The view's body.
        public var body: some View
        {
            Text( MarkdownInlineRenderer.attributedString( for: self.inlines ) )
                .fixedSize( horizontal: false, vertical: true )
        }
    }

    #Preview
    {
        MarkdownParagraphView(
            inlines:
            [
                .text( "A paragraph with " ),
                .strong( [ .text( "bold" ) ] ),
                .text( " and " ),
                .emphasis( [ .text( "italic" ) ] ),
                .text( " text." ),
            ]
        )
        .padding()
        .frame( width: 300 )
    }

#endif
