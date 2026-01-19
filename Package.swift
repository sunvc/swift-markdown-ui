// swift-tools-version:6.0

import PackageDescription

let package = Package(
  name: "swift-markdown-ui",
  platforms: [
    .macOS(.v13),
    .iOS(.v16),
    .tvOS(.v16),
    .macCatalyst(.v16),
    .watchOS(.v9),
  ],
  products: [
    .library(
      name: "MarkdownUI",
      targets: ["MarkdownUI"]
    ),
    .library(
      name: "Splash",
      targets: ["Splash"]
    )
  ],
  dependencies: [
    .package(url: "https://github.com/swiftlang/swift-cmark", from: "0.7.1"),
    .package(url: "https://github.com/sunvc/swiftui-math", branch: "main"),
  ],
  targets: [
    .target(
      name: "MarkdownUI",
      dependencies: [
        .product(name: "cmark-gfm", package: "swift-cmark"),
        .product(name: "cmark-gfm-extensions", package: "swift-cmark"),
        .product(name: "SwiftUIMath", package: "swiftui-math"),
      ]
    ),
    .target(name: "Splash",dependencies: []),
  ]
)
