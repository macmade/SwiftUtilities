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

    /// A small capsule-shaped label, such as a license name or a short tag.
    ///
    /// The pill renders its text in a compact, caption-scale font on a subtle
    /// translucent background with a matching border, so it stays legible over
    /// varied surfaces in both light and dark appearances. It derives its whole
    /// appearance from a single tint color used at full strength for the text and
    /// at low opacity for the background and border. The tint defaults to the
    /// primary content color, which lets the pill adapt to the surrounding context
    /// without hard-coding any palette, while a consumer can pass a custom color to
    /// produce a tinted badge. The font and weight are likewise configurable, so the
    /// pill can be scaled to fit different contexts while defaulting to a compact,
    /// caption-scale look. The view is purely presentational and composable, so
    /// consumer applications can reuse it wherever a compact badge is needed.
    public struct Pill: View
    {
        /// The text displayed inside the pill.
        private let text: String

        /// The tint color driving the pill's appearance.
        ///
        /// Used at full strength for the text and at low opacity for the background
        /// and border.
        private let color: Color

        /// The font of the pill's text.
        private let font: Font

        /// The weight applied to the pill's font.
        private let weight: Font.Weight

        /// Creates a pill displaying the given text.
        ///
        /// - Parameters:
        ///   - text:   The text to display inside the pill.
        ///   - color:  The tint color driving the pill's appearance. Defaults to the
        ///             primary content color.
        ///   - font:   The font of the pill's text. Defaults to the caption font.
        ///   - weight: The weight applied to the pill's font. Defaults to medium.
        public init( _ text: String, color: Color = .primary, font: Font = .caption, weight: Font.Weight = .medium )
        {
            self.text   = text
            self.color  = color
            self.font   = font
            self.weight = weight
        }

        /// The view's content.
        public var body: some View
        {
            Text( self.text )
                .font( self.font )
                .fontWeight( self.weight )
                .lineLimit( 1 )
                .foregroundStyle( self.color )
                .padding( .horizontal, 8 )
                .padding( .vertical, 2 )
                .background( self.color.opacity( 0.08 ), in: Capsule() )
                .overlay( Capsule().stroke( self.color.opacity( 0.15 ) ) )
        }
    }

    #Preview
    {
        VStack( spacing: 12 )
        {
            Pill( "MIT" )
            Pill( "Apache-2.0" )
            Pill( "GPL-3.0", color: .orange )
            Pill( "BSD-3-Clause", color: .blue, font: .body, weight: .bold )
        }
        .padding()
    }

#endif
