// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "Translator",
  platforms: [
    .macOS(.v13)
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser.git", .upToNextMajor(from: "1.0.0")),
  ],
  targets: [
    .executableTarget(
      name: "Translator",
      dependencies: [
        .product(name: "ArgumentParser", package: "swift-argument-parser")
      ]),
  ]
)
