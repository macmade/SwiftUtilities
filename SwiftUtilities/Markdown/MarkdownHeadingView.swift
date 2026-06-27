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

    /// Renders a Markdown heading.
    ///
    /// The heading's inline content is rendered with ``MarkdownInlineRenderer``
    /// and shown at a font size derived from the heading level.
    internal struct MarkdownHeadingView: View
    {
        /// The heading level (`1` is the largest).
        private let level: Int

        /// The heading's inline content.
        private let inlines: [ MarkdownInline ]

        /// Creates a heading view.
        ///
        /// - Parameters:
        ///   - level:   The heading level (`1` is the largest).
        ///   - inlines: The heading's inline content.
        init( level: Int, inlines: [ MarkdownInline ] )
        {
            self.level   = level
            self.inlines = inlines
        }

        /// The view's body.
        var body: some View
        {
            Text( MarkdownInlineRenderer.attributedString( for: self.inlines ) )
                .font( self.font( forLevel: self.level ) )
                .bold()
                .fixedSize( horizontal: false, vertical: true )
        }

        /// The font to use for a heading of the given level.
        ///
        /// - Parameter level: The heading level (`1` is the largest).
        ///
        /// - Returns: The SwiftUI font for that level.
        private func font( forLevel level: Int ) -> Font
        {
            switch level
            {
                case 1:  return .title
                case 2:  return .title2
                case 3:  return .title3
                case 4:  return .headline
                case 5:  return .subheadline
                default: return .footnote
            }
        }
    }

#endif
