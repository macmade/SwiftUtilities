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

/// A failure raised when a downloaded update cannot run on the host operating system.
///
/// Raised by ``DeploymentTargetVerifier`` when a candidate bundle's declared
/// minimum system version is newer than the host's. The versions are carried as
/// human-readable strings so the message is self-contained across the XPC boundary.
public enum DeploymentTargetError: Error, Equatable, Sendable
{
    /// The update requires a newer operating system than the host provides.
    ///
    /// - Parameters:
    ///   - required: The minimum operating-system version the update declares.
    ///   - host:     The host's operating-system version.
    case incompatible( required: String, host: String )
}

extension DeploymentTargetError: LocalizedError
{
    /// A human-readable description of the error.
    ///
    /// This message is a plain-English string rather than a ``Localization`` lookup:
    /// the error is thrown inside the bundled updater service, whose target does not
    /// embed the framework's strings table. Like the other install-composition errors
    /// (``UpdateInstallError``, ``CodeSignatureError``, ``ArchiveExtractionError``) it
    /// carries its message as text, which is what crosses the XPC boundary to the
    /// window's failure state.
    public var errorDescription: String?
    {
        switch self
        {
            case .incompatible( let required, let host ):

                return "This update requires macOS \( required ) or later, but this Mac is running macOS \( host )."
        }
    }
}
