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

/// Locates the framework-bundled updater XPC service and reports its availability.
///
/// In-app update is the single XPC-based path, and it only works when the updater
/// service is embedded in the framework. That is the case for the Xcode framework
/// distribution, but **not** for the SwiftPM package (which cannot carry a nested
/// signed service) — there the service is absent and the flow must fall back to the
/// link path. ``isAvailable`` is the runtime signal driving that decision.
public enum UpdaterServiceLocator
{
    /// The bundle identifier of the updater XPC service.
    ///
    /// This is both the service's `CFBundleIdentifier` and the name the client
    /// passes to `NSXPCConnection(serviceName:)`.
    public static let serviceName = "com.xs-labs.SwiftUtilities.Updater"

    /// Whether the bundled updater service is present and can be reached.
    ///
    /// `true` only when the service bundle is found inside the framework (see
    /// ``serviceURL``); the caller should fall back to the link path otherwise.
    public static var isAvailable: Bool
    {
        UpdaterServiceLocator.serviceURL != nil
    }

    /// The location of the bundled updater service, if present.
    ///
    /// The service is embedded in the framework's `XPCServices` directory. Because a
    /// framework is a versioned bundle, this checks the versioned location and the
    /// unversioned bundle root, returning the first that exists.
    public static var serviceURL: URL?
    {
        let bundle    = Bundle( for: UpdaterService.self )
        let component = "XPCServices/Updater.xpc"

        let candidates =
        [
            bundle.bundleURL.appendingPathComponent( "Versions/Current/\( component )" ),
            bundle.bundleURL.appendingPathComponent( "Contents/\( component )" ),
            bundle.bundleURL.appendingPathComponent( component ),
        ]

        return candidates.first { FileManager.default.fileExists( atPath: $0.path ) }
    }
}
