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

struct Test_Benchmark
{
    @Test
    func returnsValue() async throws
    {
        let value = Benchmark.run( label: "Foo" )
        {
            123
        }

        #expect( value == 123 )
    }

    @Test
    func throwError() async throws
    {
        enum TestError: Error
        {
            case failure
        }

        do
        {
            try Benchmark.run( label: "Foo" )
            {
                throw TestError.failure
            }

            #expect( Bool( false ) )
        }
        catch is TestError
        {
            #expect( Bool( true ) )
        }
        catch
        {
            #expect( Bool( false ) )
        }
    }

    @Test
    func execute() async throws
    {
        var didRun = false

        Benchmark.run( label: "Foo" )
        {
            didRun = true
        }

        #expect( didRun == true )
    }

    @Test
    func reportsThroughOutputHandler() async throws
    {
        var captured: String?

        let value = Benchmark.run( label: "Foo", output: { captured = $0 } )
        {
            123
        }

        #expect( value == 123 )
        #expect( captured?.hasPrefix( "Benchmarking - Foo: " ) == true )
        #expect( captured?.hasSuffix( " seconds" )             == true )
    }

    @Test
    func reportsSecondsWithFixedPrecision() async throws
    {
        var captured: String?

        Benchmark.run( label: "Foo", output: { captured = $0 } )
        {}

        let message = try #require( captured )
        let number  = try #require( message.split( separator: " " ).dropLast().last )

        // Fixed nine-decimal formatting: no scientific notation, exactly nine
        // fractional digits regardless of the measured magnitude.
        #expect( number.contains( "e" )                    == false )
        #expect( number.contains( "E" )                    == false )
        #expect( number.split( separator: "." ).last?.count == 9 )
    }

    @Test
    func reportsThroughOutputHandlerAsync() async throws
    {
        var captured: String?

        let value = await Benchmark.run( label: "Foo", output: { captured = $0 } )
        {
            try? await Task.sleep( nanoseconds: 1_000_000 )

            return 123
        }

        #expect( value == 123 )
        #expect( captured?.hasPrefix( "Benchmarking - Foo: " ) == true )
        #expect( captured?.hasSuffix( " seconds" )             == true )
    }

    @Test
    func returnsValueAsync() async throws
    {
        let value = await Benchmark.run( label: "Foo" )
        {
            try? await Task.sleep( nanoseconds: 1_000_000 )

            return 123
        }

        #expect( value == 123 )
    }

    @Test
    func throwErrorAsync() async throws
    {
        enum TestError: Error
        {
            case failure
        }

        do
        {
            try await Benchmark.run( label: "Foo" )
            {
                try await Task.sleep( nanoseconds: 1_000_000 )

                throw TestError.failure
            }

            #expect( Bool( false ) )
        }
        catch is TestError
        {
            #expect( Bool( true ) )
        }
        catch
        {
            #expect( Bool( false ) )
        }
    }
}
