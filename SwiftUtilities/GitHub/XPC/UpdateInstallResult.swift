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

/// The terminal outcome the updater service reports back to the app.
///
/// It is delivered through the reply block of
/// ``UpdaterServiceProtocol/installUpdate(_:withReply:)`` in its
/// ``XPCMessage/encoded()`` `Data` form. A failure carries a human-readable
/// `reason` — rather than a typed error — so it survives the process boundary
/// intact and is ready to surface to the user; the service maps its underlying
/// error to a reason with ``failure(from:)``.
public enum UpdateInstallResult: XPCMessage, Equatable
{
    /// The update was installed and a relaunch was arranged.
    case success

    /// The update could not be installed.
    ///
    /// - Parameter reason: A human-readable description of the failure.
    case failure( reason: String )

    /// Builds a failure result from an error, using its user-facing message.
    ///
    /// A `LocalizedError` with an `errorDescription` contributes that description;
    /// any other error contributes its `localizedDescription`. This is where a
    /// typed error is reduced to the string `reason` that crosses the connection.
    ///
    /// - Parameter error: The error that caused the installation to fail.
    ///
    /// - Returns: A ``failure(reason:)`` carrying the error's message.
    public static func failure( from error: any Error ) -> UpdateInstallResult
    {
        if let localized = error as? LocalizedError, let description = localized.errorDescription
        {
            return .failure( reason: description )
        }

        return .failure( reason: error.localizedDescription )
    }
}
