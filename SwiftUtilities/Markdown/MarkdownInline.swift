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

/// An inline element within a block.
///
/// Containers (emphasis, strong, strikethrough, links) hold their own inline
/// children so nested styling is preserved.
public indirect enum MarkdownInline: Equatable
{
    /// A run of plain text.
    case text( String )

    /// Emphasized (typically italic) inline content.
    case emphasis( [ MarkdownInline ] )

    /// Strongly emphasized (typically bold) inline content.
    case strong( [ MarkdownInline ] )

    /// Struck-through inline content.
    case strikethrough( [ MarkdownInline ] )

    /// Inline code, rendered verbatim in a monospaced font.
    case code( String )

    /// A hyperlink, with its destination (or `nil` when absent) and inline content.
    case link( destination: String?, children: [ MarkdownInline ] )

    /// An explicit line break (a hard break within a paragraph).
    case lineBreak

    /// A soft break (a single newline in the source), rendered as a space.
    case softBreak
}
