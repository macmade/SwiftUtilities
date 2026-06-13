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

/// A lightweight error carrying a single human-readable message.
///
/// Conforms to `LocalizedError` and `CustomStringConvertible`, so the message
/// is surfaced both through `errorDescription` and through string interpolation.
public struct RuntimeError: LocalizedError, CustomStringConvertible, Equatable
{
    /// The human-readable message describing the error.
    private let message: String

    /// Creates an error with the given message.
    ///
    /// - Parameter message: A human-readable description of the error.
    public init( message: String )
    {
        self.message = message
    }

    /// A textual representation of the error, equal to its message.
    public var description: String
    {
        self.message
    }

    /// A localized description of the error, equal to its message.
    public var errorDescription: String?
    {
        self.message
    }
}
