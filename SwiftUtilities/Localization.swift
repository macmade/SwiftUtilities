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

/// Localized-string lookup for the framework's own resources.
///
/// Centralizes resolution of the framework's `Localizable.strings` table so every
/// component localizes its user-facing text the same way, regardless of whether
/// the library is built through Swift Package Manager or as an Xcode framework.
internal enum Localization
{
    /// The bundle holding the framework's localized resources.
    ///
    /// Resolves to the Swift Package Manager resource bundle when built through
    /// SPM, and to the framework's own bundle otherwise.
    private static var bundle: Bundle
    {
        #if SWIFT_PACKAGE
        return Bundle.module
        #else
        return Bundle( for: BundleToken.self )
        #endif
    }

    /// Looks up a localized string from the framework's strings table.
    ///
    /// - Parameter key: The `Localizable.strings` key to look up.
    ///
    /// - Returns: The value localized for the current locale, or `key` itself if
    ///            no entry is found.
    internal static func string( _ key: String ) -> String
    {
        NSLocalizedString( key, bundle: Localization.bundle, comment: "" )
    }
}

#if !SWIFT_PACKAGE

/// Anchors ``Bundle(for:)`` to the framework bundle when the library is built
/// outside Swift Package Manager, where `Bundle.module` is unavailable.
private final class BundleToken
{}

#endif
