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

/// A failure raised by the in-app update client (``XPCUpdateInstaller``).
///
/// These describe why the hand-off to the bundled updater service did not result
/// in an installed update. Transport-level failures (a dropped or refused
/// connection) surface as the underlying error from the connection; these cases
/// describe failures specific to the update hand-off itself.
public enum UpdateInstallError: Error, Equatable, Sendable
{
    /// The bundled updater service could not be reached.
    ///
    /// Availability is normally decided up front by
    /// ``UpdaterServiceLocator/isAvailable`` (which routes to the link path when the
    /// service is absent), so this is a defensive case for a connection that is
    /// established but whose remote interface is unexpectedly unusable; it surfaces
    /// to the user as an error.
    case serviceUnavailable

    /// The service ran the install and reported that it failed.
    ///
    /// - Parameter reason: The human-readable reason reported by the service.
    case installationFailed( reason: String )
}

extension UpdateInstallError: LocalizedError
{
    /// A human-readable description of the error.
    public var errorDescription: String?
    {
        switch self
        {
            case .serviceUnavailable:

                return "The updater service is not available."

            case .installationFailed( let reason ):

                return reason
        }
    }
}
