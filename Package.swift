// swift-tools-version:5.9
import PackageDescription

let package = Package(
  name: "HyloSpecParser",
    products: [
        .library(
            name: "ParserGenerator",
            targets: ["ParseGen"]),
    ],

  dependencies: [
    .package(url: "https://github.com/dabrahams/citron.git", from: "2.1.5"),
  ],

  targets: [

    .target(name: "Utils"),
    .target(
      name: "SourcesAndDiagnostics",
      dependencies: [
        "Utils"
      ]),

    .target(
      name: "ParseGen",
      dependencies: [
        "Utils", "SourcesAndDiagnostics", .product(name: "CitronParserModule", package: "citron")
      ],

      exclude: ["README.md"],
      plugins: [ .plugin(name: "CitronParserGenerator", package: "citron") ]
    ),

    .testTarget(
      name: "ParseGenTests",
      dependencies: ["ParserGenerator", "Utils"]),
  ])
