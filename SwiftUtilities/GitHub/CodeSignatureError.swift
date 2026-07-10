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

/// A failure raised while inspecting or validating an application's code signature.
///
/// These describe why a ``CodeSignatureValidator`` refused an update: the code
/// could not be read, its signing identity was unusable, the requirement was
/// malformed, or the candidate did not satisfy the requirement. Each carries a
/// human-readable reason (derived from the Security framework where applicable)
/// suitable for surfacing to the user.
public enum CodeSignatureError: Error, Equatable, Sendable
{
    /// A code object could not be created for the bundle at the given path.
    ///
    /// - Parameter reason: A human-readable description of the failure.
    case staticCodeUnavailable( reason: String )

    /// The signing identity (identifier or Team ID) could not be read from the code.
    ///
    /// - Parameter reason: A human-readable description of the failure.
    case signingIdentityUnavailable( reason: String )

    /// The requirement string could not be compiled into a code requirement.
    ///
    /// - Parameter reason: A human-readable description of the failure.
    case requirementInvalid( reason: String )

    /// The candidate did not satisfy the requirement derived from the running application.
    ///
    /// - Parameter reason: A human-readable description of the failure.
    case validationFailed( reason: String )
}

extension CodeSignatureError: LocalizedError
{
    /// A human-readable description of the error.
    public var errorDescription: String?
    {
        switch self
        {
            case .staticCodeUnavailable( let reason ):        return reason
            case .signingIdentityUnavailable( let reason ):   return reason
            case .requirementInvalid( let reason ):           return reason
            case .validationFailed( let reason ):             return reason
        }
    }
}
