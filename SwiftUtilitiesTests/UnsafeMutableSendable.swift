/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2025, Jean-David Gadina - www.xs-labs.com
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

struct Test_UnsafeMutableSendable
{
    @Test
    func value() async throws
    {
        let value   = 42
        let wrapper = UnsafeMutableSendable( value )

        #expect( wrapper.value == value )
    }

    @Test
    func valueReference() async throws
    {
        class Foo
        {}

        let value   = Foo()
        let wrapper = UnsafeMutableSendable( value )

        #expect( wrapper.value === value )
    }

    @Test
    func valueMutation() async throws
    {
        struct Foo
        {
            var bar: Int = 0
        }

        var value   = Foo()
        value.bar   = 10
        let wrapper = UnsafeMutableSendable( value )

        #expect( wrapper.value.bar == 10 )

        wrapper.value.bar = 20

        #expect( wrapper.value.bar == 20 )
    }

    @Test
    func valueReferenceMutation() async throws
    {
        class Foo
        {
            var bar: Int = 0
        }

        let value   = Foo()
        value.bar   = 10
        let wrapper = UnsafeMutableSendable( value )

        #expect( wrapper.value.bar == 10 )

        wrapper.value.bar = 20

        #expect( wrapper.value.bar == 20 )
    }
}
