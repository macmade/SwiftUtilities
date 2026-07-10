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

/// The request the app sends to the bundled updater service to install an update.
///
/// It carries everything the service needs to run the install composition off the
/// sandbox: the downloaded `archive`, the `target` application bundle to replace,
/// the `requirement` the extracted application must satisfy, the archive `format`,
/// and the `processIdentifier` of the running application so the service can wait
/// for it to exit before relaunching.
///
/// The **app** derives the expected `requirement` from its own validated running
/// identity (the root of trust), because the service cannot: reading its own
/// identity would pin the service's signing identifier, not the application's. The
/// service therefore verifies the extracted application against this requirement
/// rather than deriving one. This trusts the caller to supply a strong requirement,
/// so the service must independently confirm the connecting client's identity (via
/// its audit token) before acting — a constraint for the service milestone.
///
/// File locations travel as POSIX paths rather than `URL`s so the wire form is an
/// unambiguous string; ``archiveURL`` and ``targetURL`` reconstruct file URLs from
/// them.
public struct UpdateInstallRequest: XPCMessage, Equatable
{
    /// The POSIX path of the downloaded archive to install.
    public let archivePath: String

    /// The POSIX path of the application bundle to replace.
    public let targetPath: String

    /// The Code Signing Requirement Language string the extracted application must
    /// satisfy before it can replace the target.
    public let requirement: String

    /// The archive's format.
    public let format: UpdateArchiveFormat

    /// The process identifier of the running application, used to wait for it to
    /// exit before relaunching.
    public let processIdentifier: Int32

    /// Creates an install request.
    ///
    /// - Parameters:
    ///   - archive:           A file URL to the downloaded archive.
    ///   - target:            A file URL to the application bundle to replace.
    ///   - requirement:       The requirement the extracted application must satisfy.
    ///   - format:            The archive's format.
    ///   - processIdentifier: The running application's process identifier.
    public init( archive: URL, target: URL, requirement: String, format: UpdateArchiveFormat, processIdentifier: Int32 )
    {
        self.archivePath       = archive.path
        self.targetPath        = target.path
        self.requirement       = requirement
        self.format            = format
        self.processIdentifier = processIdentifier
    }

    /// A file URL to the downloaded archive.
    public var archiveURL: URL
    {
        URL( fileURLWithPath: self.archivePath )
    }

    /// A file URL to the application bundle to replace.
    public var targetURL: URL
    {
        URL( fileURLWithPath: self.targetPath )
    }
}
