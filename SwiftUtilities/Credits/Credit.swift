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

/// Describes a single third-party project credited in the Credits window.
///
/// A credit carries everything the window needs to present one project: its
/// name and author, a human-readable description, an optional website link, and
/// the name and full text of the license it is distributed under. It is a plain
/// value type that the consumer application assembles and hands to the window,
/// so it carries no presentation logic of its own.
///
/// The type is `Identifiable` — its ``id`` is the project ``name`` — and
/// `Hashable`, so it can drive a `NavigationSplitView` selection directly.
public struct Credit: Identifiable, Hashable
{
    /// The project's name.
    public let name: String

    /// The project's author.
    public let author: String

    /// A human-readable description of the project.
    public let description: String

    /// The project's website, or `nil` when it has none.
    public let website: URL?

    /// The name of the license the project is distributed under, shown as a pill.
    public let licenseName: String

    /// The full text of the project's license.
    public let licenseText: String

    /// The credit's stable identity, which is the project ``name``.
    public var id: String
    {
        self.name
    }

    /// Creates a credit describing a single third-party project.
    ///
    /// - Parameters:
    ///   - name:        The project's name.
    ///   - author:      The project's author.
    ///   - description: A human-readable description of the project.
    ///   - website:     The project's website, or `nil` when it has none.
    ///   - licenseName: The name of the license, shown as a pill.
    ///   - licenseText: The full text of the project's license.
    public init( name: String, author: String, description: String, website: URL?, licenseName: String, licenseText: String )
    {
        self.name        = name
        self.author      = author
        self.description = description
        self.website     = website
        self.licenseName = licenseName
        self.licenseText = licenseText
    }
}
