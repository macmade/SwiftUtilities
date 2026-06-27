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

internal import Markdown

/// Parses Markdown text into a presentation-agnostic block model.
///
/// The mapping covers headings, paragraphs, the inline styles used by release
/// notes (emphasis, strong, strikethrough, inline code, links, breaks), code
/// blocks, ordered and unordered lists (including nesting and task-list
/// checkboxes), block quotes, and thematic breaks. Nodes outside this subset
/// (tables, images, raw HTML, and so on) are dropped, so the renderer never has
/// to handle them.
internal enum MarkdownContent
{
    /// Parses a Markdown string into an array of ``MarkdownBlock`` values.
    ///
    /// - Parameter markdown: The Markdown source to parse.
    ///
    /// - Returns: The top-level blocks of the document, in order.
    static func parse( _ markdown: String ) -> [ MarkdownBlock ]
    {
        MarkdownContent.blocks( from: Document( parsing: markdown ) )
    }

    /// Maps the block-level children of a markup node into ``MarkdownBlock`` values.
    ///
    /// - Parameter markup: The container whose children are block-level nodes.
    ///
    /// - Returns: The mapped blocks, with unsupported nodes dropped.
    private static func blocks( from markup: Markup ) -> [ MarkdownBlock ]
    {
        markup.children.compactMap { MarkdownContent.block( from: $0 ) }
    }

    /// Maps a single block-level markup node into a ``MarkdownBlock``.
    ///
    /// - Parameter markup: The block-level node to map.
    ///
    /// - Returns: The mapped block, or `nil` for an unsupported node.
    private static func block( from markup: Markup ) -> MarkdownBlock?
    {
        switch markup
        {
            case let heading as Heading:

                return .heading( level: heading.level, inlines: MarkdownContent.inlines( from: heading ) )

            case let paragraph as Paragraph:

                return .paragraph( inlines: MarkdownContent.inlines( from: paragraph ) )

            case let list as UnorderedList:

                return .unorderedList( items: MarkdownContent.listItems( from: list ) )

            case let list as OrderedList:

                return .orderedList( start: Int( list.startIndex ), items: MarkdownContent.listItems( from: list ) )

            case let quote as BlockQuote:

                return .blockQuote( blocks: MarkdownContent.blocks( from: quote ) )

            case let code as CodeBlock:

                return .codeBlock( language: code.language, code: code.code )

            case is ThematicBreak:

                return .thematicBreak

            default:

                return nil
        }
    }

    /// Maps the list items of a list node into ``MarkdownListItem`` values.
    ///
    /// - Parameter list: The ordered or unordered list whose children are items.
    ///
    /// - Returns: The mapped list items.
    private static func listItems( from list: Markup ) -> [ MarkdownListItem ]
    {
        list.children.compactMap { $0 as? ListItem }.map
        {
            MarkdownListItem( checkbox: MarkdownContent.checkbox( from: $0.checkbox ), blocks: MarkdownContent.blocks( from: $0 ) )
        }
    }

    /// Maps a `swift-markdown` checkbox into a ``MarkdownCheckbox``.
    ///
    /// - Parameter checkbox: The parsed checkbox, or `nil` for a non-task item.
    ///
    /// - Returns: The mapped checkbox state, or `nil`.
    private static func checkbox( from checkbox: Checkbox? ) -> MarkdownCheckbox?
    {
        switch checkbox
        {
            case .checked:   return .checked
            case .unchecked: return .unchecked
            case nil:        return nil
        }
    }

    /// Maps the inline children of a markup node into ``MarkdownInline`` values.
    ///
    /// - Parameter markup: The container whose children are inline nodes.
    ///
    /// - Returns: The mapped inlines, with unsupported nodes dropped.
    private static func inlines( from markup: Markup ) -> [ MarkdownInline ]
    {
        markup.children.compactMap { MarkdownContent.inline( from: $0 ) }
    }

    /// Maps a single inline markup node into a ``MarkdownInline``.
    ///
    /// - Parameter markup: The inline node to map.
    ///
    /// - Returns: The mapped inline, or `nil` for an unsupported node.
    private static func inline( from markup: Markup ) -> MarkdownInline?
    {
        switch markup
        {
            case let text as Text:                   return .text( text.string )
            case let code as InlineCode:             return .code( code.code )
            case let emphasis as Emphasis:           return .emphasis( MarkdownContent.inlines( from: emphasis ) )
            case let strong as Strong:               return .strong( MarkdownContent.inlines( from: strong ) )
            case let strikethrough as Strikethrough: return .strikethrough( MarkdownContent.inlines( from: strikethrough ) )
            case let link as Link:                   return .link( destination: link.destination, children: MarkdownContent.inlines( from: link ) )
            case is LineBreak:                       return .lineBreak
            case is SoftBreak:                       return .softBreak
            default:                                 return nil
        }
    }
}
