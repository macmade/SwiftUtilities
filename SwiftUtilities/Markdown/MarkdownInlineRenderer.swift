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

import Foundation

/// Builds an `AttributedString` from inline Markdown elements.
///
/// Styling is expressed with `inlinePresentationIntent`, which composes across
/// nesting (for example strong inside emphasis), and with the `link` attribute
/// for hyperlinks. The resulting string is rendered by the heading and
/// paragraph views; SwiftUI's `Text` resolves these attributes, and links open
/// in the default browser.
internal enum MarkdownInlineRenderer
{
    /// Builds an `AttributedString` for a sequence of inline elements.
    ///
    /// - Parameter inlines: The inline elements to render.
    ///
    /// - Returns: The concatenated, styled string.
    static func attributedString( for inlines: [ MarkdownInline ] ) -> AttributedString
    {
        inlines.reduce( into: AttributedString() ) { $0 += MarkdownInlineRenderer.attributedString( for: $1 ) }
    }

    /// Builds an `AttributedString` for a single inline element.
    ///
    /// - Parameter inline: The inline element to render.
    ///
    /// - Returns: The styled string.
    static func attributedString( for inline: MarkdownInline ) -> AttributedString
    {
        switch inline
        {
            case .text( let string ):

                return AttributedString( string )

            case .code( let code ):

                return MarkdownInlineRenderer.adding( .code, to: AttributedString( code ) )

            case .emphasis( let children ):

                return MarkdownInlineRenderer.adding( .emphasized, to: MarkdownInlineRenderer.attributedString( for: children ) )

            case .strong( let children ):

                return MarkdownInlineRenderer.adding( .stronglyEmphasized, to: MarkdownInlineRenderer.attributedString( for: children ) )

            case .strikethrough( let children ):

                return MarkdownInlineRenderer.adding( .strikethrough, to: MarkdownInlineRenderer.attributedString( for: children ) )

            case .link( let destination, let children ):

                var string = MarkdownInlineRenderer.attributedString( for: children )

                if let destination, let url = URL( string: destination )
                {
                    string.link = url
                }

                return string

            case .lineBreak:

                return AttributedString( "\n" )

            case .softBreak:

                return AttributedString( " " )
        }
    }

    /// Adds an inline presentation intent to every run of a string.
    ///
    /// The intent is unioned with any intent already present, so nested styles
    /// (such as strong within emphasis) accumulate rather than overwrite one
    /// another.
    ///
    /// - Parameters:
    ///   - intent: The intent to add.
    ///   - string: The string to style.
    ///
    /// - Returns: The styled string.
    private static func adding( _ intent: InlinePresentationIntent, to string: AttributedString ) -> AttributedString
    {
        var result = string

        result.runs.forEach
        {
            let existing = result[ $0.range ].inlinePresentationIntent ?? []

            result[ $0.range ].inlinePresentationIntent = existing.union( intent )
        }

        return result
    }
}
