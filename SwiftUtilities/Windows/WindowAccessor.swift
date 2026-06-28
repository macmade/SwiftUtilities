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

    /// A zero-size SwiftUI bridge that hands back the `NSWindow` hosting a view, so
    /// window-level AppKit configuration SwiftUI does not expose — such as
    /// centering a window — can be performed.
    ///
    /// Place it in a `.background(...)`; ``WindowResolvingView`` invokes the
    /// callback each time the window is shown (and re-arms after each close) — no
    /// polling and no dispatched deferral. For example, to center a SwiftUI
    /// `Settings` window, which the system does not position declaratively:
    ///
    /// ```swift
    /// PreferencesView()
    ///     .background( WindowAccessor { $0.center() } )
    /// ```
    public struct WindowAccessor: NSViewRepresentable
    {
        /// Called with the hosting window each time it is shown.
        private let onWindowShown: ( NSWindow ) -> Void

        /// Creates the accessor.
        ///
        /// - Parameter onWindowShown: Called each time the hosting window is shown.
        public init( onWindowShown: @escaping ( NSWindow ) -> Void )
        {
            self.onWindowShown = onWindowShown
        }

        /// Creates the probe view that reports its window once shown.
        ///
        /// - Parameter context: The representable context.
        /// - Returns: The probe view.
        public func makeNSView( context: Context ) -> WindowResolvingView
        {
            let view           = WindowResolvingView()
            view.onWindowShown = self.onWindowShown

            return view
        }

        /// Keeps the callback current.
        ///
        /// - Parameters:
        ///   - nsView:  The probe view.
        ///   - context: The representable context.
        public func updateNSView( _ nsView: WindowResolvingView, context: Context )
        {
            nsView.onWindowShown = self.onWindowShown
        }
    }

#endif
