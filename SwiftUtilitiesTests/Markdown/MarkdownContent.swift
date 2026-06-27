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
@testable import SwiftUtilities
import Testing

struct Test_MarkdownContent
{
    @Test
    func parsesHeadingWithLevel() async throws
    {
        #expect( MarkdownContent.parse( "# Title" )     == [ .heading( level: 1, inlines: [ .text( "Title" ) ] ) ] )
        #expect( MarkdownContent.parse( "### Deeper" )  == [ .heading( level: 3, inlines: [ .text( "Deeper" ) ] ) ] )
    }

    @Test
    func parsesParagraphWithInlineStyling() async throws
    {
        let blocks = MarkdownContent.parse( "Plain *em* **strong** `code` ~~gone~~." )

        #expect( blocks == [
            .paragraph( inlines: [
                .text( "Plain " ),
                .emphasis( [ .text( "em" ) ] ),
                .text( " " ),
                .strong( [ .text( "strong" ) ] ),
                .text( " " ),
                .code( "code" ),
                .text( " " ),
                .strikethrough( [ .text( "gone" ) ] ),
                .text( "." ),
            ] ),
        ] )
    }

    @Test
    func parsesLinkWithDestinationAndChildren() async throws
    {
        let blocks = MarkdownContent.parse( "See [the docs](https://example.com/docs)." )

        #expect( blocks == [
            .paragraph( inlines: [
                .text( "See " ),
                .link( destination: "https://example.com/docs", children: [ .text( "the docs" ) ] ),
                .text( "." ),
            ] ),
        ] )
    }

    @Test
    func parsesCodeBlockWithLanguage() async throws
    {
        let blocks = MarkdownContent.parse( "```swift\nlet x = 1\n```" )

        #expect( blocks == [ .codeBlock( language: "swift", code: "let x = 1\n" ) ] )
    }

    @Test
    func parsesCodeBlockWithoutLanguage() async throws
    {
        let blocks = MarkdownContent.parse( "```\nplain\n```" )

        #expect( blocks == [ .codeBlock( language: nil, code: "plain\n" ) ] )
    }

    @Test
    func parsesOrderedListWithStartIndex() async throws
    {
        let blocks = MarkdownContent.parse( "3. first\n4. second" )

        #expect( blocks == [
            .orderedList( start: 3, items: [
                MarkdownListItem( checkbox: nil, blocks: [ .paragraph( inlines: [ .text( "first" ) ] ) ] ),
                MarkdownListItem( checkbox: nil, blocks: [ .paragraph( inlines: [ .text( "second" ) ] ) ] ),
            ] ),
        ] )
    }

    @Test
    func parsesNestedUnorderedList() async throws
    {
        let blocks = MarkdownContent.parse( "- a\n    - b" )

        #expect( blocks == [
            .unorderedList( items: [
                MarkdownListItem( checkbox: nil, blocks: [
                    .paragraph( inlines: [ .text( "a" ) ] ),
                    .unorderedList( items: [
                        MarkdownListItem( checkbox: nil, blocks: [ .paragraph( inlines: [ .text( "b" ) ] ) ] ),
                    ] ),
                ] ),
            ] ),
        ] )
    }

    @Test
    func parsesTaskListCheckboxes() async throws
    {
        let blocks = MarkdownContent.parse( "- [x] done\n- [ ] todo" )

        #expect( blocks == [
            .unorderedList( items: [
                MarkdownListItem( checkbox: .checked,   blocks: [ .paragraph( inlines: [ .text( "done" ) ] ) ] ),
                MarkdownListItem( checkbox: .unchecked, blocks: [ .paragraph( inlines: [ .text( "todo" ) ] ) ] ),
            ] ),
        ] )
    }

    @Test
    func parsesBlockQuote() async throws
    {
        let blocks = MarkdownContent.parse( "> quoted" )

        #expect( blocks == [
            .blockQuote( blocks: [ .paragraph( inlines: [ .text( "quoted" ) ] ) ] ),
        ] )
    }

    @Test
    func parsesThematicBreak() async throws
    {
        #expect( MarkdownContent.parse( "---" ) == [ .thematicBreak ] )
    }

    @Test
    func returnsEmptyForEmptyInput() async throws
    {
        #expect( MarkdownContent.parse( "" ).isEmpty )
    }
}
