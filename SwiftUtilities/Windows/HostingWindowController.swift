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
    import SwiftUI

    /// A base class hosting a single SwiftUI-backed window and owning its lifetime.
    ///
    /// Subclasses expose a typed entry point that calls ``show(using:_:)`` and
    /// builds their content through ``present(rootView:sizing:configure:)``. The
    /// base enforces a single live window per concrete subclass: the controllers
    /// are held in a shared registry keyed by their type, so repeating the command
    /// brings the existing window to the front instead of opening another. A
    /// controller releases itself when its window closes (via `NSWindowDelegate`).
    ///
    /// Keying the registry by subclass — rather than giving each subclass its own
    /// `static` reference — works around Swift's lack of static stored properties on
    /// generic types while still keeping the single-window rule in one place.
    @MainActor
    public class HostingWindowController: NSObject, NSWindowDelegate
    {
        /// How a hosted window is sized before being centered.
        enum Sizing
        {
            /// Use a fixed content size.
            case fixed( NSSize )

            /// Size the window to fit its hosted content.
            case fitContent
        }

        /// The live controllers, keyed by concrete subclass.
        ///
        /// Holding the controller here both enforces the single-window rule and
        /// keeps the controller alive while its window is on screen.
        private static var shared = [ ObjectIdentifier : HostingWindowController ]()

        /// The hosted window, while it is on screen.
        private var window: NSWindow?

        /// Shows the single window for the calling subclass, reusing the existing one if open.
        ///
        /// If a window is already on screen for the subclass, it is brought to the
        /// front; otherwise `make` creates a controller and `body` builds its window,
        /// typically by calling ``present(rootView:sizing:configure:)``.
        ///
        /// - Parameters:
        ///   - make: Creates the controller when no window is currently open.
        ///   - body: Builds and shows the newly created controller's window.
        static func show<T: HostingWindowController>( using make: () -> T, _ body: ( T ) -> Void )
        {
            let key = ObjectIdentifier( T.self )

            if let existing = HostingWindowController.shared[ key ]
            {
                existing.bringToFront()

                return
            }

            let controller = make()

            HostingWindowController.shared[ key ] = controller

            body( controller )
        }

        /// Builds, centers, and shows a window hosting the given SwiftUI view.
        ///
        /// - Parameters:
        ///   - rootView:  The SwiftUI view to host.
        ///   - sizing:    How the window is sized before being centered.
        ///   - configure: Applies the subclass-specific window chrome (title, style
        ///                mask, …) before the window is sized and centered.
        func present( rootView: some View, sizing: Sizing, configure: ( NSWindow ) -> Void )
        {
            let hosting           = NSHostingController( rootView: rootView )
            hosting.sizingOptions = .preferredContentSize

            let window                  = NSWindow( contentViewController: hosting )
            window.delegate             = self
            window.isReleasedWhenClosed = false

            configure( window )

            // Size the window before centering, so the SwiftUI content does not
            // resize it away from the centered position afterwards.
            switch sizing
            {
                case .fixed( let size ): window.setContentSize( size )
                case .fitContent:        window.setContentSize( hosting.view.fittingSize )
            }

            window.center()

            self.window = window

            self.bringToFront()
        }

        /// Activates the application and brings the window to the front.
        func bringToFront()
        {
            NSApp.activate( ignoringOtherApps: true )
            self.window?.makeKeyAndOrderFront( nil )
        }

        /// Closes the hosted window, which in turn releases the controller.
        func close()
        {
            self.window?.close()
        }

        /// Releases the window and the shared controller reference when the window closes.
        ///
        /// - Parameter notification: The `NSWindow.willCloseNotification` notification.
        public func windowWillClose( _ notification: Notification )
        {
            self.window = nil

            HostingWindowController.shared[ ObjectIdentifier( type( of: self ) ) ] = nil
        }
    }

#endif
