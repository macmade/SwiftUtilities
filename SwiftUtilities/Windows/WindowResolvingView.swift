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

#if canImport( AppKit )

    import AppKit

    /// An invisible view that reports its hosting `NSWindow` each time that window
    /// is shown — its first `becomeKey`, and again after every close — so a reused
    /// window (one that is hidden rather than destroyed on close, such as a
    /// SwiftUI `Settings` window) can be re-centered on every reopen.
    ///
    /// Reporting on `becomeKey` rather than in `viewDidMoveToWindow()` matters: the
    /// latter fires before the window is positioned, so acting there is overridden
    /// by the system's placement. The alternating key/close observers carry the
    /// "waiting to be shown" vs "waiting to be closed" state, so no flag is needed
    /// and a mere refocus never re-triggers. Used through ``WindowAccessor``.
    public final class WindowResolvingView: NSView
    {
        /// Called each time the hosting window is shown.
        public var onWindowShown: ( ( NSWindow ) -> Void )?

        /// Arms reporting for the current window: reports now if it is already key,
        /// otherwise waits for it to become key.
        public override func viewDidMoveToWindow()
        {
            super.viewDidMoveToWindow()

            guard let window = self.window
            else
            {
                return
            }

            if window.isKeyWindow
            {
                self.report( window )
            }
            else
            {
                self.armForShow( window )
            }
        }

        /// Observes the window's next `becomeKey`.
        ///
        /// - Parameter window: The window to observe.
        private func armForShow( _ window: NSWindow )
        {
            NotificationCenter.default.addObserver( self, selector: #selector( self.windowDidBecomeKey( _: ) ), name: NSWindow.didBecomeKeyNotification, object: window )
        }

        /// Reports the window the first time it becomes key, then waits for it to
        /// close so it can be re-armed for the next showing.
        ///
        /// - Parameter notification: The key-window notification.
        @objc
        private func windowDidBecomeKey( _ notification: Notification )
        {
            guard let window = notification.object as? NSWindow
            else
            {
                return
            }

            NotificationCenter.default.removeObserver( self, name: NSWindow.didBecomeKeyNotification, object: window )

            self.report( window )
        }

        /// Reports the window and arms re-reporting for after it closes.
        ///
        /// - Parameter window: The window being shown.
        private func report( _ window: NSWindow )
        {
            self.onWindowShown?( window )

            NotificationCenter.default.addObserver( self, selector: #selector( self.windowWillClose( _: ) ), name: NSWindow.willCloseNotification, object: window )
        }

        /// Re-arms reporting for the next showing once the window closes.
        ///
        /// - Parameter notification: The will-close notification.
        @objc
        private func windowWillClose( _ notification: Notification )
        {
            guard let window = notification.object as? NSWindow
            else
            {
                return
            }

            NotificationCenter.default.removeObserver( self, name: NSWindow.willCloseNotification, object: window )

            self.armForShow( window )
        }
    }

#endif
