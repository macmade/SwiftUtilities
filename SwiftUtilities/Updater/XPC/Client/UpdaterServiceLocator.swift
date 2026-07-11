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

/// Locates the host application's bundled updater XPC service and reports its
/// availability.
///
/// In-app update is the single XPC-based path, and it only works when the updater
/// service is embedded in the **application** at `Contents/XPCServices/Updater.xpc`:
/// that is the only location `launchd` registers an app's on-demand XPC service, so
/// it is the only place `NSXPCConnection(serviceName:)` can resolve it. An XPC
/// service nested inside an embedded framework is *not* registered, so the service
/// cannot simply ride along inside `SwiftUtilities.framework` — the app must copy it
/// into its own `Contents/XPCServices` (see the README). Where the service is absent
/// — notably the SwiftPM package, which cannot carry a nested signed service — the
/// flow must fall back to the link path. ``isAvailable`` is the runtime signal
/// driving that decision.
public enum UpdaterServiceLocator
{
    /// The bundle identifier of the updater XPC service.
    ///
    /// This is both the service's `CFBundleIdentifier` and the name the client
    /// passes to `NSXPCConnection(serviceName:)`.
    public static let serviceName = "com.xs-labs.SwiftUtilities.Updater"

    /// Whether the bundled updater service is present and can be reached.
    ///
    /// `true` only when the service bundle is found in the application's
    /// `Contents/XPCServices` (see ``serviceURL``); the caller should fall back to
    /// the link path otherwise.
    public static var isAvailable: Bool
    {
        UpdaterServiceLocator.serviceURL != nil
    }

    /// The location of the bundled updater service, if present.
    ///
    /// The service must be embedded in the host application's `Contents/XPCServices`
    /// directory — the location `launchd` scans to register the app's on-demand XPC
    /// services. This checks for it there, relative to the main bundle, and returns
    /// its URL only if it exists.
    public static var serviceURL: URL?
    {
        let url = Bundle.main.bundleURL.appendingPathComponent( "Contents/XPCServices/Updater.xpc" )

        return FileManager.default.fileExists( atPath: url.path ) ? url : nil
    }
}
