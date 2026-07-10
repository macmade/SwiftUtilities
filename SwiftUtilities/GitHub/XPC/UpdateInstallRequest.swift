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
/// the expected signing `identity` the extracted application must match, the
/// archive `format`, and the `processIdentifier` of the running application so the
/// service can wait for it to exit before relaunching.
///
/// The **app** supplies its own validated running ``CodeSigningIdentity`` (the root
/// of trust), because the service cannot derive it: reading its own identity would
/// pin the service's signing identifier, not the application's. The service rebuilds
/// the requirement from this identity with the vetted, injection-safe
/// ``CodeSigningIdentity/requirement`` builder — it never executes a raw
/// requirement string chosen by the caller — and verifies the extracted application
/// against it. Because the identity is still caller-supplied, the service must also
/// independently confirm the connecting client's identity (via its audit token)
/// before acting — a constraint enforced by the service's listener.
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

    /// The signing identity the extracted application must match before it can
    /// replace the target. The service rebuilds the code requirement from it.
    public let identity: CodeSigningIdentity

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
    ///   - identity:          The signing identity the extracted application must match.
    ///   - format:            The archive's format.
    ///   - processIdentifier: The running application's process identifier.
    public init( archive: URL, target: URL, identity: CodeSigningIdentity, format: UpdateArchiveFormat, processIdentifier: Int32 )
    {
        self.archivePath       = archive.path
        self.targetPath        = target.path
        self.identity          = identity
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
