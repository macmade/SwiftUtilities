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

/// A block-level element of rendered Markdown.
///
/// This is a presentation-agnostic view model: ``MarkdownContent/parse(_:)``
/// maps a `swift-markdown` syntax tree into an array of these, and a renderer
/// (such as `MarkdownView` on platforms with SwiftUI) turns them into views.
/// Keeping the mapping pure makes it unit-testable without any UI.
///
/// Only the subset of Markdown used by release notes is modeled; unsupported
/// nodes are dropped during parsing (see ``MarkdownContent/parse(_:)``).
public enum MarkdownBlock: Equatable
{
    /// A heading, with its level (`1` through `6`) and inline content.
    case heading( level: Int, inlines: [ MarkdownInline ] )

    /// A paragraph of inline content.
    case paragraph( inlines: [ MarkdownInline ] )

    /// A bulleted list.
    case unorderedList( items: [ MarkdownListItem ] )

    /// A numbered list, with the number of its first item.
    case orderedList( start: Int, items: [ MarkdownListItem ] )

    /// A block quote, holding its own nested blocks.
    case blockQuote( blocks: [ MarkdownBlock ] )

    /// A fenced or indented code block, with its optional language and verbatim code.
    case codeBlock( language: String?, code: String )

    /// A horizontal rule.
    case thematicBreak
}
