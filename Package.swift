// swift-tools-version:5.9
import PackageDescription

let package = Package(
  name: "HyloSpecParser",

  products: [
    .library(
      name: "HyloEBNF",
      targets: ["HyloEBNF"]),
  ],

  dependencies: [
    .package(url: "https://github.com/dabrahams/citron.git", from: "2.1.5"),
  ],

  targets: [

    .target(
      name: "HyloEBNF",
      dependencies: [
        .product(name: "CitronParserModule", package: "citron")
      ],

      exclude: ["README.md"],
      plugins: [ .plugin(name: "CitronParserGenerator", package: "citron") ]
    ),

    .testTarget(
      name: "HyloEBNFTests",
      dependencies: ["HyloEBNF"]),
  ])
