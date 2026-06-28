SwiftUtilities
==============

[![Build Status](https://img.shields.io/github/actions/workflow/status/macmade/SwiftUtilities/ci-mac.yaml?label=macOS&logo=apple)](https://github.com/macmade/SwiftUtilities/actions/workflows/ci-mac.yaml)
[![Issues](http://img.shields.io/github/issues/macmade/SwiftUtilities.svg?logo=github)](https://github.com/macmade/SwiftUtilities/issues)
![Status](https://img.shields.io/badge/status-active-brightgreen.svg?logo=git)
![License](https://img.shields.io/badge/license-mit-brightgreen.svg?logo=open-source-initiative)  
[![Contact](https://img.shields.io/badge/follow-@macmade-blue.svg?logo=twitter&style=social)](https://twitter.com/macmade)
[![Sponsor](https://img.shields.io/badge/sponsor-macmade-pink.svg?logo=github-sponsors&style=social)](https://github.com/sponsors/macmade)

### About

Miscellaneous Swift utilities for macOS (15+) apps: a GitHub-releases update
checker, a SwiftUI Markdown renderer, a generic About window, a window-hosting
base class, a SwiftUI window accessor, a lightweight benchmarking helper, a
simple error type, and `Sendable` escape hatches.

### Installation

Add the package to your `Package.swift` dependencies:

```swift
.package( url: "https://github.com/macmade/SwiftUtilities.git", branch: "main" )
```

Then add `SwiftUtilities` to your target's dependencies. The library can also be
used directly through its Xcode project.

### Components

#### GitHubUpdater

Checks a GitHub repository's releases and reports whether a newer version of the
running application is available. Drafts and pre-releases are ignored, and
`v`-prefixed tags are normalized before comparison.

On AppKit platforms, the up-to-date and error outcomes are shown as modal
alerts, while an available update opens a non-modal window that renders the
release notes as Markdown and offers Download, View on GitHub, and Later.

```swift
import SwiftUtilities

// The running app's name and version are read from its Info.plist.
let updater = GitHubUpdater( owner: "macmade", repository: "SwiftUtilities" )

// Platform-agnostic: get the outcome as a value.
let result = await updater?.performUpdateCheck()

// On AppKit platforms, present the outcome to the user:
updater?.checkForUpdates()             // reports every outcome
updater?.checkForUpdatesInBackground() // only when an update is available
```

#### MarkdownView

Renders a Markdown string as native SwiftUI views: headings, paragraphs,
ordered and unordered lists (including nesting and task-list checkboxes), block
quotes, code blocks, thematic breaks, and inline styles. Unsupported nodes
(tables, images, raw HTML) are dropped. The presentation-agnostic model is also
available directly through `MarkdownContent.parse(_:)`.

```swift
MarkdownView( "# Title\n\nSome **release notes**." )
```

#### AboutWindowController

Shows a generic, reusable About window for the running application. By default
the name, version, and copyright are read from the bundle's `Info.plist` and the
icon from the application, so no arguments are required.

```swift
AboutWindowController.show()
```

The values can also be supplied explicitly. The `Bundle` extension exposes
`title`, `version`, and `copyright` for reuse:

```swift
AboutWindowController.show(
    applicationName: Bundle.main.title,
    version:         Bundle.main.version,
    copyright:       Bundle.main.copyright,
    icon:            NSApp.applicationIconImage
)
```

#### HostingWindowController

An `open` base class for hosting a single SwiftUI-backed `NSWindow` and owning
its lifetime. It enforces one live window per subclass — reusing the existing
one instead of opening another — and releases itself when the window closes.
`AboutWindowController` is built on it; subclass it to host your own windows.

#### WindowAccessor

A zero-size SwiftUI bridge that hands back the `NSWindow` hosting a view, for
window-level AppKit configuration SwiftUI does not expose — such as centering a
`Settings` window. Drop it in a `.background(...)`; the callback fires each time
the window is shown (re-armed after each close, so a reused window re-centers on
every reopen), without polling or dispatched deferral.

```swift
PreferencesView()
    .background( WindowAccessor { $0.center() } )
```

#### Benchmark

Measures how long a closure takes to run, forwarding the closure's result and
reporting the elapsed time. Synchronous and asynchronous closures are both
supported, and the output can be redirected.

```swift
let value = Benchmark.run( label: "Parsing" )
{
    parse( data )
}
// Prints: "Benchmarking - Parsing: 0.004186500 seconds"

// Asynchronous work:
let fetched = try await Benchmark.run( label: "Fetch" )
{
    try await fetch()
}

// Redirect the output instead of printing:
Benchmark.run( label: "Work", output: { logger.log( $0 ) } )
{
    doWork()
}
```

#### RuntimeError

A lightweight `LocalizedError` carrying a single human-readable message.

```swift
throw RuntimeError( message: "Something went wrong" )
```

#### UnsafeSendable / UnsafeMutableSendable

Boxes that make a value `Sendable` without compiler verification — deliberate
escape hatches where the caller takes responsibility for safe sharing.
`UnsafeSendable` wraps an immutable value; `UnsafeMutableSendable` wraps a
mutable, **unsynchronized** value.

```swift
let box = UnsafeSendable( nonSendableValue )
// Pass `box` across concurrency domains, then read box.value.

let counter = UnsafeMutableSendable( 0 )
counter.value += 1 // Not synchronized: the caller must serialize access.
```

### Cloning

This project uses submodules.  
To clone it, use the following command:

```bash
git clone --recursive https://github.com/macmade/SwiftUtilities.git
```

License
-------

Project is released under the terms of the MIT License.

Repository Infos
----------------

    Owner:          Jean-David Gadina - XS-Labs
    Web:            www.xs-labs.com
    Blog:           www.noxeos.com
    Twitter:        @macmade
    GitHub:         github.com/macmade
    LinkedIn:       ch.linkedin.com/in/macmade/
    StackOverflow:  stackoverflow.com/users/182676/macmade
