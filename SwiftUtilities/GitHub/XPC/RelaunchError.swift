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

/// A failure raised while relaunching the application after an update.
public enum RelaunchError: Error, Equatable, Sendable
{
    /// The application did not exit within the allotted time, so it was not
    /// reopened (reopening while the old copy still runs would just reactivate it).
    case timedOutWaitingForExit

    /// The relaunch invocation was missing or malformed.
    case invalidInvocation

    /// The detached relaunch process could not be started.
    ///
    /// - Parameter code: The `posix_spawn` error code.
    case relaunchProcessFailed( code: Int32 )
}

extension RelaunchError: LocalizedError
{
    /// A human-readable description of the error.
    public var errorDescription: String?
    {
        switch self
        {
            case .timedOutWaitingForExit:

                return "The application did not quit in time to be relaunched."

            case .invalidInvocation:

                return "The relaunch could not be started because its arguments were invalid."

            case .relaunchProcessFailed( let code ):

                return "The relaunch process could not be started (error \( code ))."
        }
    }
}
