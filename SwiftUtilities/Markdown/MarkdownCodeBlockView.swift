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

    /// Renders a Markdown code block.
    ///
    /// The code is shown verbatim in a monospaced font on a subtly tinted,
    /// rounded background, and is selectable. The single trailing newline that
    /// the parser keeps on fenced code is trimmed for display.
    internal struct MarkdownCodeBlockView: View
    {
        /// The verbatim code to display.
        private let code: String

        /// Creates a code-block view.
        ///
        /// - Parameter code: The verbatim code to display.
        init( code: String )
        {
            self.code = code
        }

        /// The view's body.
        var body: some View
        {
            Text( self.displayedCode )
                .font( .system( .body, design: .monospaced ) )
                .textSelection( .enabled )
                .frame( maxWidth: .infinity, alignment: .leading )
                .padding( 10 )
                .background( Color.secondary.opacity( 0.12 ), in: RoundedRectangle( cornerRadius: 6 ) )
        }

        /// The code with its single trailing newline removed, for display.
        private var displayedCode: String
        {
            self.code.hasSuffix( "\n" ) ? String( self.code.dropLast() ) : self.code
        }
    }

#endif
