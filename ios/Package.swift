// swift-tools-version:5.9
//
// The recorder's core, without React, as a Swift package so that it can be tested on its own (`yarn test:ios`).
// Apps get these sources through the pod (ScreenRecord.podspec), not through this package.
import PackageDescription

let package = Package(
  name: "ScreenRecordCore",
  platforms: [.iOS(.v15)],
  products: [
    .library(name: "ScreenRecordCore", targets: ["ScreenRecordCore"])
  ],
  targets: [
    .target(
      name: "ScreenRecordCore",
      path: "Core",
      publicHeadersPath: ".",
      linkerSettings: [
        .linkedFramework("AVFoundation"),
        .linkedFramework("CoreMedia"),
        .linkedFramework("CoreVideo"),
        .linkedFramework("QuartzCore"),
        .linkedFramework("UIKit"),
      ]
    ),
    .testTarget(
      name: "ScreenRecordCoreTests",
      dependencies: ["ScreenRecordCore"],
      path: "Tests/ScreenRecordCoreTests"
    ),
  ]
)
