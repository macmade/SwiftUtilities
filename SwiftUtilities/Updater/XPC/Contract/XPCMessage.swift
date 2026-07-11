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

/// A value type exchanged across the updater XPC connection, serialized to `Data`.
///
/// `NSXPCConnection` only transports values whose classes conform to
/// `NSSecureCoding`; `Data` (bridged to `NSData`) is one of the types it allows by
/// default, whereas an arbitrary Swift value type is not. Rather than turn every
/// message into an `NSObject` subclass adopting `NSSecureCoding` — which would cost
/// the messages their value semantics and require each argument class to be
/// whitelisted with `setClasses(_:for:argumentIndex:ofReply:)` — a message
/// serializes itself to `Data`, which is what the ``UpdaterServiceProtocol`` and
/// ``UpdaterClientProtocol`` methods carry over the wire.
///
/// This keeps the messages pure Swift value types living in the platform-agnostic
/// layer, and makes their wire form fully unit-testable through an encode → decode
/// round-trip, independent of any live connection.
public protocol XPCMessage: Codable, Sendable
{}

public extension XPCMessage
{
    /// Serializes the message to its `Data` wire form.
    ///
    /// - Returns: The encoded message, suitable for sending across the connection.
    ///
    /// - Throws: An error if the message cannot be encoded.
    func encoded() throws -> Data
    {
        try JSONEncoder().encode( self )
    }

    /// Decodes a message from its `Data` wire form.
    ///
    /// - Parameter data: An encoded message, as produced by ``encoded()``.
    ///
    /// - Returns: The decoded message.
    ///
    /// - Throws: An error if `data` is not a valid encoding of `Self`.
    static func decoded( from data: Data ) throws -> Self
    {
        try JSONDecoder().decode( Self.self, from: data )
    }
}
