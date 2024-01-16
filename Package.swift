// swift-tools-version:5.9
import PackageDescription

let CitronParser
  = Target.Dependency.product(name: "CitronParserModule", package: "citron")
let CitronLexer
  = Target.Dependency.product(  name: "CitronLexerModule", package: "citron")

let package = Package(
  name: "HyloSpecParser",

  dependencies: [
    .package(
      url: "https://github.com/loftware/Zip2Collection.git",
      from: "0.1.0"
    ),

    .package(url: "https://github.com/dabrahams/citron.git", from: "2.1.5"),
  ],

  targets: [

    .target(
      name: "Utils",
      dependencies: [
        .product(name: "LoftDataStructures_Zip2Collection", package: "Zip2Collection")]
    ),

    .target(
      name: "ParseGen",
      dependencies: [
        "Utils", CitronLexer, CitronParser
      ],

      exclude: ["README.md"],
      plugins: [ .plugin(name: "CitronParserGenerator", package: "citron") ]
    ),

    .testTarget(
      name: "ParseGenTests",
      dependencies: [CitronLexer, "ParseGen", "Utils"]),
  ])
