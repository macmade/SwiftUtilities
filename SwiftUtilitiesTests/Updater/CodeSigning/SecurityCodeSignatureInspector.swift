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

#if canImport( Security )

    import Foundation
    @testable import SwiftUtilities
    import Testing

    /// Exercises the real Security-backed inspector's error and rejection paths.
    /// The positive validation path requires a properly signed application bundle
    /// and is verified manually rather than in CI (see the type's documentation).
    struct Test_SecurityCodeSignatureInspector
    {
        @Test
        func verifyThrowsForNonexistentBundle() async throws
        {
            let inspector = SecurityCodeSignatureInspector()
            let missing   = URL( fileURLWithPath: NSTemporaryDirectory() ).appendingPathComponent( "missing-\( UUID().uuidString ).app" )

            #expect( throws: (any Error).self )
            {
                try inspector.verify( bundleAt: missing, satisfies: "anchor apple generic" )
            }
        }

        @Test
        func verifyRejectsUnsignedFile() async throws
        {
            let inspector = SecurityCodeSignatureInspector()
            let unsigned  = URL( fileURLWithPath: NSTemporaryDirectory() ).appendingPathComponent( "unsigned-\( UUID().uuidString ).bin" )

            try Data( "not a signed app".utf8 ).write( to: unsigned )

            defer
            {
                try? FileManager.default.removeItem( at: unsigned )
            }

            #expect( throws: CodeSignatureError.self )
            {
                try inspector.verify( bundleAt: unsigned, satisfies: "anchor apple generic" )
            }
        }
    }

#endif
