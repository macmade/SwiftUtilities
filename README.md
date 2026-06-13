SwiftUtilities
==============

[![Build Status](https://img.shields.io/github/actions/workflow/status/macmade/SwiftUtilities/ci-mac.yaml?label=macOS&logo=apple)](https://github.com/macmade/SwiftUtilities/actions/workflows/ci-mac.yaml)
[![Issues](http://img.shields.io/github/issues/macmade/SwiftUtilities.svg?logo=github)](https://github.com/macmade/SwiftUtilities/issues)
![Status](https://img.shields.io/badge/status-active-brightgreen.svg?logo=git)
![License](https://img.shields.io/badge/license-mit-brightgreen.svg?logo=open-source-initiative)  
[![Contact](https://img.shields.io/badge/follow-@macmade-blue.svg?logo=twitter&style=social)](https://twitter.com/macmade)
[![Sponsor](https://img.shields.io/badge/sponsor-macmade-pink.svg?logo=github-sponsors&style=social)](https://github.com/sponsors/macmade)

### About

Miscellaneous Swift utilities for macOS apps: a GitHub-releases update checker,
a lightweight benchmarking helper, a simple error type, and `Sendable` escape
hatches.

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

```swift
import SwiftUtilities

// The running app's name and version are read from its Info.plist.
let updater = GitHubUpdater( owner: "macmade", repository: "SwiftUtilities" )

// Platform-agnostic: get the outcome as a value.
let result = await updater?.performUpdateCheck()

// On AppKit platforms, present the outcome as an NSAlert:
updater?.checkForUpdates()             // alerts for every outcome
updater?.checkForUpdatesInBackground() // only alerts when an update is available
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
