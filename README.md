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
checker, a SwiftUI Markdown renderer, a generic About window, a licenses &
credits window, a reusable capsule label, a window-hosting base class, a SwiftUI
window accessor, a lightweight benchmarking helper, a simple error type, and
`Sendable` escape hatches.

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

##### In-app updates

By default, choosing to update opens the release's download page in the browser
(*link* mode, available in every distribution). On the Xcode framework
distribution, the updater can instead download, verify, install, and relaunch
the new version in place. Opt in at construction:

```swift
let updater = GitHubUpdater(
    owner:      "macmade",
    repository: "SwiftUtilities",
    behavior:   .inApp
)
```

The in-app path runs through a small XPC service, `Updater.xpc`, that performs
the privileged file work the application itself cannot. Because a sandboxed app
cannot replace itself, the service runs *off the sandbox*: the update window
downloads the release asset, then the service validates the download's code
signature against the running application's identity (same signing identifier and
Team ID) and replaces the application on disk. The relaunch is a separate,
user-confirmed step driven by the app itself — the service cannot do it, having
just replaced its own containing bundle — so when the user chooses to relaunch,
the app reopens into the new version. If any step fails, or the release asset is
not a supported archive (`.zip` or `.dmg`), the window falls back to the link
behavior, so the release always stays reachable.

**In-app updates require the Xcode project's products.** A Swift Package Manager
`.library` cannot embed and sign a nested XPC service, so under SwiftPM only the
link update is available: the service is absent, and `behavior: .inApp`
transparently falls back to the link window at runtime. Use the Xcode project's
`SwiftUtilities.framework` and `Updater.xpc` products to offer in-app updates.

**Embedding the service.** The service must live at
`YourApp.app/Contents/XPCServices/Updater.xpc`. That is the only location
`launchd` registers an application's on-demand XPC service, and therefore the only
place `NSXPCConnection(serviceName:)` can resolve it — a service left nested inside
an embedded framework is **not** registered and will not be found. In your app
target:

1. Embed `SwiftUtilities.framework` as usual (*Frameworks, Libraries, and
   Embedded Content* → *Embed & Sign*).
2. Add a **Copy Files** build phase, set its destination to **XPC Services**, and
   add `Updater.xpc` to it. Xcode copies the service into `Contents/XPCServices`
   and re-signs it with your identity as part of signing the app.

**Signing requirements.** Both the app and the service must be signed with *your*
identity, because:

- The service authenticates its client *by team*: it refuses any connection from
  a process not signed by the **same Apple Developer Team ID** as the service.
  Signing both with your identity makes the teams match — the *Embed & Sign* and
  *Copy Files* phases above do this for you.
- The service is **non-sandboxed** (it carries no App Sandbox entitlement) so it
  can write to `/Applications` and relaunch; sign it with the **hardened
  runtime**, as for any Developer ID distribution.
- The client connects to the service by its bundle identifier,
  `com.xs-labs.SwiftUtilities.Updater`; keep that identifier on the service.

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

#### CreditsWindowController

Shows a reusable Licenses & Credits window listing the third-party projects an
application uses. The window is a two-pane split view: a sidebar of credited
projects — sorted alphabetically — driving a detail pane that shows the selected
project's author, description, an optional website link, and its full license
text in a scrollable area. It opens at a sensible size and stays resizable and,
like the About window, brings the existing window to the front instead of
opening a second one.

Each project is described by a `Credit` value. The whole window content is also
available as the `CreditsView` SwiftUI view, for embedding it somewhere other
than the managed window.

```swift
CreditsWindowController.show(
    credits: [
        Credit(
            name:        "SwiftUtilities",
            author:      "Jean-David Gadina",
            description: "A collection of reusable Swift utilities.",
            website:     URL( string: "https://github.com/macmade/SwiftUtilities" ),
            licenseName: "MIT",
            licenseText: "The MIT License (MIT) …"
        )
    ]
)
```

#### Pill

A small, public SwiftUI view rendering a short label inside a rounded capsule —
used for the license badges in the Credits window, and reusable on its own. The
tint color, font, and weight are all configurable and default to a compact,
caption-scale look that reads well in both light and dark.

```swift
Pill( "MIT" )
Pill( "GPL-3.0", color: .orange )
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
