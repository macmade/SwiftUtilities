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

/// A single item of an ordered or unordered list.
///
/// An item holds its own blocks, so nested lists and multi-paragraph items are
/// represented naturally. `checkbox` is non-`nil` for GitHub task-list items.
public struct MarkdownListItem: Equatable
{
    /// The task-list checkbox state, or `nil` when the item is not a task-list item.
    public let checkbox: MarkdownCheckbox?

    /// The item's block content.
    public let blocks: [ MarkdownBlock ]

    /// Creates a list item.
    ///
    /// - Parameters:
    ///   - checkbox: The task-list checkbox state, or `nil`.
    ///   - blocks:   The item's block content.
    public init( checkbox: MarkdownCheckbox?, blocks: [ MarkdownBlock ] )
    {
        self.checkbox = checkbox
        self.blocks   = blocks
    }
}
