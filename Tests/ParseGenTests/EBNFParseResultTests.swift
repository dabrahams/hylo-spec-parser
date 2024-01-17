import XCTest
@testable import ParseGen
import Utils
import SourcesAndDiagnostics

let sampleFile = thisFilePath()
let sampleStartLine = thisLine() + 2
private let sample = source("""
a ::=
  b c

b ::= (one of)
  0 ?

c ::= (token)
  '0b'? d+
  (x y | q)*

d ::= (regexp)
  [^']

e ::=
  f g

f ::=
  f | g
""")

func ebnf(_ source: GrammarSource) throws -> EBNF.DefinitionList {
  let p = EBNFParser()
  for t in EBNF.tokens(
        in: source.text, onLine: source.startLine, fromFile: source.sourceFilePath)
  {
    try p.consume(token: t, code: t.id)
  }
  return try p.endParsing()
}

final class EBNFParseResultTests: XCTestCase {

  func test() throws {
    let ast = try ebnf(sample)

    let l = SourceRange.none
    let m = Incidental(l)

    let expected: EBNF.DefinitionList = [
      .init(
        kind: .plain, lhs: .init("a", at: l),
        alternatives: [
          [.symbol(.init("b", at: l)), .symbol(.init("c", at: l))]]),

      .init(
        kind: .oneOf, lhs: .init("b", at: l),
        alternatives: [
          [.literal("0", position: m)], [.literal("?", position: m)]
        ]),

      .init(
        kind: .token, lhs: .init("c", at: l),
        alternatives: [
          [
            .quantified(
              .literal("0b", position: m), "?", position: m),
            .quantified(
              .symbol(.init("d", at: l)), "+", position: m),
          ],
          [
            .quantified(
              .group(
                [
                  [.symbol(.init("x", at: l)), .symbol(.init("y", at: l))],
                  [.symbol(.init("q", at: l))]
                ]), "*", position: m)
          ]
        ]),

      .init(
        kind: .regexp, lhs: .init("d", at: l),
        alternatives: [
          [
            .regexp("[^']", position: m)
          ]
        ]),

      .init(
        kind: .plain, lhs: .init("e", at: l),
        alternatives: [
            [.symbol(.init("f", at: l)), .symbol(.init("g", at: l))]
        ]),

      .init(
        kind: .plain, lhs: .init("f", at: l),
        alternatives: [
          [.group([[.symbol(.init("f", at: l))], [.symbol(.init("g", at: l))]])]
        ])
    ]

    for (a, x) in zip(ast, expected) {
      XCTAssertEqual(a.lhs, x.lhs)
      XCTAssertEqual(a.kind, x.kind)
      XCTAssertEqual(a.alternatives.count, x.alternatives.count)
      for (a1, x1) in zip(a.alternatives, x.alternatives) {
        XCTAssertEqual(a1.count, x1.count)
        for (a2, x2) in zip(a1, x1) {
          XCTAssertEqual(a2, x2)
        }
        XCTAssertEqual(a1, x1)
      }
    }
    XCTAssertEqual(ast.count, expected.count)
  }

}
