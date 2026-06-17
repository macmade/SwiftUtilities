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

/// A namespace of helpers for measuring how long a piece of work takes to run.
///
/// Use `run(label:output:action:)` to time a closure; the measured duration is
/// passed to `output` (printing to the standard output by default) and the
/// closure's result is returned unchanged.
public enum Benchmark
{
    /// Measures how long a synchronous closure takes to run and reports the result.
    ///
    /// The elapsed time, prefixed with `label`, is passed to `output`, and the
    /// value returned by `action` is forwarded to the caller. Any error thrown by
    /// `action` is rethrown.
    ///
    /// - Parameters:
    ///   - label:  A human-readable name used to identify the measurement in the output.
    ///   - output: A closure receiving the formatted measurement. Defaults to printing to the standard output.
    ///   - action: The closure whose execution time is measured.
    ///
    /// - Returns: The value returned by `action`.
    ///
    /// - Throws: Any error thrown by `action`.
    public static func run< T >( label: String, output: ( String ) -> Void = { print( $0 ) }, action: () throws -> T ) rethrows -> T
    {
        let clock  = ContinuousClock()
        let start  = clock.now
        let result = try action()

        Benchmark.report( label: label, duration: clock.now - start, output: output )

        return result
    }

    /// Measures how long an asynchronous closure takes to run and reports the result.
    ///
    /// The elapsed time, prefixed with `label`, is passed to `output`, and the
    /// value returned by `action` is forwarded to the caller. Any error thrown by
    /// `action` is rethrown.
    ///
    /// - Parameters:
    ///   - label:  A human-readable name used to identify the measurement in the output.
    ///   - output: A closure receiving the formatted measurement. Defaults to printing to the standard output.
    ///   - action: The asynchronous closure whose execution time is measured.
    ///
    /// - Returns: The value returned by `action`.
    ///
    /// - Throws: Any error thrown by `action`.
    public static func run< T >( label: String, output: ( String ) -> Void = { print( $0 ) }, action: () async throws -> T ) async rethrows -> T
    {
        let clock  = ContinuousClock()
        let start  = clock.now
        let result = try await action()

        Benchmark.report( label: label, duration: clock.now - start, output: output )

        return result
    }

    /// Formats the measured `duration` and passes the result to `output`.
    ///
    /// The elapsed time is rendered with nine decimal places (nanosecond
    /// resolution), so the output is stable and never falls back to scientific
    /// notation regardless of how short or long the measurement is.
    ///
    /// - Parameters:
    ///   - label:    A human-readable name used to identify the measurement in the output.
    ///   - duration: The measured elapsed time.
    ///   - output:   A closure receiving the formatted measurement.
    private static func report( label: String, duration: Duration, output: ( String ) -> Void )
    {
        let seconds   = Double( duration.components.seconds ) + Double( duration.components.attoseconds ) * 1e-18
        let formatted = String( format: "%.9f", seconds )

        output( "Benchmarking - \( label ): \( formatted ) seconds" )
    }
}
