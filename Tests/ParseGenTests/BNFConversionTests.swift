import XCTest

import HyloEBNF

private struct TestBuilder {
  typealias Symbol = Int
  var symbolName: [String] = []
  var symbolLocation: [SourceRange] = []
  var rules: [(lhs: Symbol, rhs: [Symbol])] = []
  var ruleLocation: [SourceRange] = []
  var startSymbol: Symbol?

  func ruleSpelling(_ i: Int) -> String {
    let rhs = rules[i].rhs.map { symbolName[$0] }.joined(separator: " ")
    return "\(symbolName[rules[i].lhs]) ::= \(rhs)"
  }

  func allRuleSpellings() -> Set<String> {
    Set(rules.indices.map(ruleSpelling))
  }

}

extension TestBuilder: BNFBuilder {

  mutating func makeTerminal<N: EBNFNode>(_ n: N) -> Symbol {
    makeSymbol(n)
  }

  mutating func makeNonterminal<N: EBNFNode>(_ n: N) -> Symbol {
    makeSymbol(n)
  }

  private mutating func makeSymbol<N: EBNFNode>(_ n: N) -> Symbol {
    symbolName.append(n.bnfSymbolName)
    symbolLocation.append(n.position)
    return symbolName.count - 1
  }

  mutating func setStartSymbol(_ s: Symbol) {
    startSymbol = s
  }

  mutating func addRule<RHS: Collection, Source: EBNFNode>(
    reducing rhs: RHS, to lhs: Symbol, source: Source
  )
  where RHS.Element == Symbol
  {
    rules.append((lhs: lhs, rhs: Array(rhs)))
    ruleLocation.append(source.position)
  }

}

func grammar(_ source: GrammarSource, startSymbol: String = "start") throws
  -> EBNF.Grammar
{
  try EBNF.Grammar(ebnf(source), start: startSymbol)
}

private func bnf(_ source: GrammarSource, startSymbol: String = "start") throws
  -> TestBuilder
{
  let g = try grammar(source, startSymbol: startSymbol)
  var conversion = EBNFToBNF(from: g, into: TestBuilder())
  conversion.build()
  return conversion.output
}


final class BNFConversionTests: XCTestCase {

  /// Called with a multiline string `grammarText` immediately following the open parenthesis
  /// (`testNoError("""`), converts `grammarText` to BNF via `TestBuilder` and passes the resulting
  /// `TestBuilder` to `body`, reporting any EBNF errors as test failures.
  private func testNoError(
    _ grammarText: String, sourceFilePath: String = #filePath, startLine: Int = #line,
    body: (TestBuilder) throws -> Void
  ) throws  {
    let s = source(grammarText, sourceFilePath: sourceFilePath, startLine: startLine)
    do {
      try body(bnf(s))
    }
    catch let e as EBNFErrorLog {
      XCTFail("Unexpected error\n\(e.report())")
    }
  }

  func testSimple() throws {
    try testNoError("""
start ::=
  'a'
""") { g in
      XCTAssertEqual(g.rules.count, 1)
      XCTAssertEqual(g.ruleSpelling(0), "start ::= 'a'")
    }
  }

  func testKleeneStar() throws {
    try testNoError("""
start ::=
  'a'*
""") { g in
      let expected: Set = [
        "start ::= `'a'*`",
        "`'a'*` ::= `'a'*` 'a'",
        "`'a'*` ::= "
      ]
      XCTAssertEqual(g.allRuleSpellings(), expected)
    }
  }

  func testKleenePlus() throws {
    try testNoError("""
start ::=
  'a'+
""") { g in
      let expected: Set = [
        "start ::= `'a'+`",
        "`'a'+` ::= `'a'+` 'a'",
        "`'a'+` ::= 'a'"
      ]
      XCTAssertEqual(g.allRuleSpellings(), expected)
    }
  }

  func testQuestion() throws {
    try testNoError("""
start ::=
  'a'?
""") { g in
      let expected: Set = [
        "start ::= `'a'?`",
        "`'a'?` ::= 'a'",
        "`'a'?` ::= "
      ]
      XCTAssertEqual(g.allRuleSpellings(), expected)
    }
  }

  func testTopLevelAlternatives() throws {
    try testNoError("""
start ::=
  'a'
  'b'
""") { g in
      let expected: Set = [
        "start ::= 'a'",
        "start ::= 'b'"
      ]
      XCTAssertEqual(g.allRuleSpellings(), expected)
    }
  }

  func testInnerAlternatives() throws {
    try testNoError("""
start ::=
  ('a' | 'b')
""") { g in
      let expected: Set = [
        "start ::= `'a' | 'b'`",
        "`'a' | 'b'` ::= 'a'",
        "`'a' | 'b'` ::= 'b'",
      ]
      XCTAssertEqual(g.allRuleSpellings(), expected)
    }
  }

  func testCompound() throws {
    try testNoError("""
start ::=
  'b'* ('c' | 'd')
""") { g in
      let expected: Set = [
        "start ::= `'b'*` `'c' | 'd'`",
        "`'b'*` ::= `'b'*` 'b'",
        "`'b'*` ::= ",
        "`'c' | 'd'` ::= 'c'",
        "`'c' | 'd'` ::= 'd'"
      ]
      XCTAssertEqual(g.allRuleSpellings(), expected)
    }
  }

  func testOneOf() throws {
    try testNoError("""
start ::= (one of)
  x y z
""") { g in
      let expected: Set = [
        "start ::= 'x'",
        "start ::= 'y'",
        "start ::= 'z'"
      ]
      XCTAssertEqual(g.allRuleSpellings(), expected)
    }
  }

  func testTokensNotIncludedInBNF() throws {
    try testNoError("""
start ::=
  a
  b c

a ::= (token)
  'x' b 'z'
  c

b ::= (one of)
  x y

c ::= (regexp)
 ( )*
""") { g in
      let expected: Set = [
        "start ::= a",
        "start ::= b c",
        "b ::= 'x'",
        "b ::= 'y'"
      ]
      XCTAssertEqual(g.allRuleSpellings(), expected)
      XCTAssert(g.symbolName.contains("a"))
    }
  }

}
