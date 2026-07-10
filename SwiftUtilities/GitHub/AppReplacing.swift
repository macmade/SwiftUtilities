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

/// Replaces an application bundle on disk with another.
///
/// This is the dependency-injection seam for the replacement building block, so
/// the installers that compose it can be exercised with a stub in place of the
/// real ``AppReplacer``.
public protocol AppReplacing: Sendable
{
    /// Replaces the application bundle at `target` with the one at `replacement`.
    ///
    /// The replacement is consumed (moved into place), so it no longer exists at
    /// its original location after a successful call.
    ///
    /// - Parameters:
    ///   - target:      A file URL to the application bundle to replace.
    ///   - replacement: A file URL to the application bundle to install.
    ///
    /// - Returns: The URL of the installed application, which may differ from
    ///   `target`.
    ///
    /// - Throws: An error if the replacement cannot be performed.
    func replaceApplication( at target: URL, with replacement: URL ) throws -> URL
}
