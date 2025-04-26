// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "GRDBCustom",
  products: [
    .library(
      name: "GRDB",
      targets: ["GRDB"]
    )
  ],
  targets: [
    .binaryTarget(
      name: "GRDB",
      path: "Binary/GRDB.xcframework"
    ),
  ]
)
