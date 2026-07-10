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

struct Test_Credit
{
    /// Builds a `Credit` with sensible defaults, overriding only the fields a
    /// given test cares about.
    private func makeCredit(
        name:        String = "Example",
        author:      String = "Jane Doe",
        description: String = "A sample project.",
        website:     URL?   = URL( string: "https://example.com" ),
        licenseName: String = "MIT",
        licenseText: String = "The MIT License (MIT)…"
    )
    -> Credit
    {
        Credit(
            name:        name,
            author:      author,
            description: description,
            website:     website,
            licenseName: licenseName,
            licenseText: licenseText
        )
    }

    @Test
    func storesAllProperties() async throws
    {
        let website = URL( string: "https://example.com" )
        let credit  = Credit(
            name:        "Example",
            author:      "Jane Doe",
            description: "A sample project.",
            website:     website,
            licenseName: "MIT",
            licenseText: "The MIT License (MIT)…"
        )

        #expect( credit.name        == "Example" )
        #expect( credit.author      == "Jane Doe" )
        #expect( credit.description == "A sample project." )
        #expect( credit.website     == website )
        #expect( credit.licenseName == "MIT" )
        #expect( credit.licenseText == "The MIT License (MIT)…" )
    }

    @Test
    func allowsMissingWebsite() async throws
    {
        let credit = self.makeCredit( website: nil )

        #expect( credit.website == nil )
    }

    @Test
    func identityMatchesName() async throws
    {
        let credit = self.makeCredit( name: "SwiftUtilities" )

        #expect( credit.id == "SwiftUtilities" )
    }

    @Test
    func equalCreditsAreEqualAndHashEqually() async throws
    {
        let a = self.makeCredit()
        let b = self.makeCredit()

        #expect( a == b )
        #expect( a.hashValue == b.hashValue )
    }

    @Test
    func differingCreditsAreNotEqual() async throws
    {
        let a = self.makeCredit( licenseName: "MIT" )
        let b = self.makeCredit( licenseName: "Apache-2.0" )

        #expect( a != b )
    }
}
