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

/// How a ``GitHubUpdater`` delivers an available update to the user.
///
/// The behavior selects what happens once the update-available window offers a
/// newer release. It is configured once, at construction, on ``GitHubUpdater``
/// (see ``GitHubUpdater/behavior``), and defaults to ``link`` so callers that do
/// nothing keep today's behavior unchanged.
///
/// Configuring it in a single place — rather than passing it to each check —
/// keeps it a single source of truth: concurrent
/// ``GitHubUpdater/checkForUpdates()`` and
/// ``GitHubUpdater/checkForUpdatesInBackground()`` calls always agree on the
/// mode. It stays a pure value type with no UI or IO, so it lives in the
/// platform-agnostic layer alongside ``UpdateCheckResult``; only the AppKit
/// presentation layer acts on it. This is the opt-in seam the in-app update
/// path plugs into.
public enum UpdateBehavior: Sendable, Equatable
{
    /// Point the user at the release for a manual download.
    ///
    /// The update-available window's **Download** action opens the release
    /// asset — or the release page — in the browser, as it always has. This is
    /// the default, and the only behavior that requires no further setup from
    /// the consumer.
    case link

    /// Download and install the update from within the application.
    ///
    /// The update-available window downloads the new build, verifies its code
    /// signature against the running application, replaces the running
    /// application on disk, and relaunches it. When in-app installation is not
    /// possible — for example when the release has no downloadable asset — the
    /// updater falls back to the ``link`` behavior so the update stays
    /// reachable.
    case inApp
}
