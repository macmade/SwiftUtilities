// swift-tools-version:6.0
/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2025, Jean-David Gadina - www.xs-labs.com
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

import PackageDescription

let package = Package(
    name: "SwiftUtilities",
    defaultLocalization: "en",
    platforms: [
        .macOS( .v15 ),
    ],
    products: [
        .library( name: "SwiftUtilities", targets: [ "SwiftUtilities" ] ),
    ],
    dependencies: [
        .package( url: "https://github.com/apple/swift-markdown.git", .upToNextMinor( from: "0.8.0" ) ),
    ],
    targets: [
        .target(
            name: "SwiftUtilities",
            dependencies: [
                .product( name: "Markdown", package: "swift-markdown" ),
            ],
            path: "SwiftUtilities",
            // In-app updates require the Xcode framework, which can embed and sign
            // the nested updater XPC service; a SwiftPM library cannot. So the
            // package provides only the download-link update: all in-app code is
            // excluded here, and the few link-path files that reference it gate
            // those references behind `#if !SWIFT_PACKAGE`.
            exclude: [
                "Updater/Download",
                "Updater/Archive",
                "Updater/CodeSigning",
                "Updater/Install",
                "Updater/Relaunch",
                "Updater/XPC",
                "Updater/UI/InAppUpdateViewModel.swift",
            ],
            resources: [
                .process( "Utilities/en.lproj" ),
            ]
        ),
        .testTarget(
            name: "SwiftUtilitiesTests",
            dependencies: [ "SwiftUtilities" ],
            path: "SwiftUtilitiesTests",
            exclude: [
                "Updater/Download",
                "Updater/Archive",
                "Updater/CodeSigning",
                "Updater/Install",
                "Updater/Relaunch",
                "Updater/XPC",
                "Updater/UI",
            ]
        ),
    ]
)
