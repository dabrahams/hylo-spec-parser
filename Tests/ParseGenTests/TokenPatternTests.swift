import XCTest
@testable import ParseGen

final class TokenPatternTests: XCTestCase {

  /// Called with a multiline string `grammarText` immediately following the open parenthesis
  /// (i.e. `testNoError("""...`), converts `grammarText` to an `EBNF.Grammar` and passes its
  /// `literals()` and `regexps()` (with keys mapped to the bare symbol name) to `body`, reporting
  /// any EBNF errors as test failures.
  private func testNoError(
    _ grammarText: String, sourceFilePath: String = #filePath, startLine: Int = #line,
    body: (_ literals: Set<String>, _ regexps: [String: String]) throws -> Void
  ) throws  {
    let s = source(grammarText, sourceFilePath: sourceFilePath, startLine: startLine)
    do {
      let g = try grammar(s)
      try body(
        g.literals(),
        Dictionary(uniqueKeysWithValues: g.regexps().map { ($0.key.name, $0.value)}))
    }
    catch let e as EBNFErrorLog {
      XCTFail("Unexpected error\n\(e.report())")
    }
  }

  func test() throws {
    try testNoError("""
start ::=
  'a' b* 'c' d e

b ::= (one of)
  x y z

d ::= (token)
  b 'q'

e ::= (regexp)
  (a|b)*
  x+
""") { literals, regexps in
      XCTAssertEqual(literals, ["c", "a", "z", "y", "x"])
      XCTAssertEqual(regexps, ["d": "(?:x|y|z)q", "e": "(?:(a|b)*|x+)"])
    }
  }

  func testRegexpsInTokens() throws {
    try testNoError("""
start ::=
  'a' b* 'c' d

b ::= (one of)
  x y z

d ::= (token)
  b 'q' e

e ::= (regexp)
  (a|b)*
  x+
""") { literals, regexps in
      XCTAssertEqual(literals, ["c", "a", "z", "y", "x"])
      XCTAssertEqual(regexps, ["d": "(?:x|y|z)q(?:(a|b)*|x+)"])
    }
  }

}
