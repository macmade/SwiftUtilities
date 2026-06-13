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

/// A namespace of helpers for measuring how long a piece of work takes to run.
///
/// Use `run(label:action:)` to time a closure; the measured duration is printed
/// to the standard output and the closure's result is returned unchanged.
public enum Benchmark
{
    /// Measures and prints how long a synchronous closure takes to run.
    ///
    /// The elapsed time is printed to the standard output, prefixed with `label`,
    /// and the value returned by `action` is forwarded to the caller. Any error
    /// thrown by `action` is rethrown.
    ///
    /// - Parameters:
    ///   - label:  A human-readable name used to identify the measurement in the output.
    ///   - action: The closure whose execution time is measured.
    ///
    /// - Returns: The value returned by `action`.
    ///
    /// - Throws: Any error thrown by `action`.
    public static func run< T >( label: String, action: () throws -> T ) rethrows -> T
    {
        let start  = DispatchTime.now()
        let result = try action()

        Benchmark.report( label: label, start: start )

        return result
    }

    /// Measures and prints how long an asynchronous closure takes to run.
    ///
    /// The elapsed time is printed to the standard output, prefixed with `label`,
    /// and the value returned by `action` is forwarded to the caller. Any error
    /// thrown by `action` is rethrown.
    ///
    /// - Parameters:
    ///   - label:  A human-readable name used to identify the measurement in the output.
    ///   - action: The asynchronous closure whose execution time is measured.
    ///
    /// - Returns: The value returned by `action`.
    ///
    /// - Throws: Any error thrown by `action`.
    public static func run< T >( label: String, action: () async throws -> T ) async rethrows -> T
    {
        let start  = DispatchTime.now()
        let result = try await action()

        Benchmark.report( label: label, start: start )

        return result
    }

    /// Computes the elapsed time since `start` and prints it to the standard output.
    ///
    /// - Parameters:
    ///   - label: A human-readable name used to identify the measurement in the output.
    ///   - start: The instant, captured with `DispatchTime.now()`, at which the measured work began.
    private static func report( label: String, start: DispatchTime )
    {
        let end         = DispatchTime.now()
        let nanoSeconds = end.uptimeNanoseconds - start.uptimeNanoseconds
        let duration    = Double( nanoSeconds ) / 1_000_000_000

        print( "Benchmarking - \( label ): \( duration ) seconds" )
    }
}
