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

    /// Observes a window's `didResizeNotification`, reporting its frame size on
    /// each resize, and removes the observation when released.
    ///
    /// A companion to ``WindowAccessor``: resolve the hosting `NSWindow` with that,
    /// then hand it here to be told of size changes — to persist a window's size
    /// across launches, say. A reference type, so it can be retained by `@State`
    /// and clean up in `deinit`, and main-actor isolated because it reads the
    /// window's frame. It uses the target/action notification API rather than the
    /// closure variant, whose block is `@Sendable` and can neither capture the
    /// non-`Sendable` callback nor touch the main-actor window under Swift 6.
    @MainActor
    public final class WindowResizeObserver: NSObject
    {
        /// The window currently being observed, held weakly so it can close freely.
        private weak var window: NSWindow?

        /// The callback invoked with the window's frame size on each resize.
        private var action: ( ( CGSize ) -> Void )?

        /// Creates an observer that is not yet watching any window.
        public override init()
        {
            super.init()
        }

        /// Starts reporting `window`'s frame size on every resize. A no-op when
        /// already observing that same window, so resolving the window again (it is
        /// shown anew) does not stack duplicate observations.
        ///
        /// - Parameters:
        ///   - window: The window to observe.
        ///   - action: Called with the window's frame size on every resize.
        public func observe( _ window: NSWindow, action: @escaping ( CGSize ) -> Void )
        {
            guard window !== self.window
            else
            {
                return
            }

            NotificationCenter.default.removeObserver( self, name: NSWindow.didResizeNotification, object: nil )

            self.window = window
            self.action = action

            NotificationCenter.default.addObserver( self, selector: #selector( self.windowDidResize( _: ) ), name: NSWindow.didResizeNotification, object: window )
        }

        /// Reports the resized window's frame size to the stored action.
        ///
        /// - Parameter notification: The resize notification; its object is the window.
        @objc
        private func windowDidResize( _ notification: Notification )
        {
            guard let window = notification.object as? NSWindow
            else
            {
                return
            }

            self.action?( window.frame.size )
        }

        deinit
        {
            NotificationCenter.default.removeObserver( self )
        }
    }

#endif
