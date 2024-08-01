import HyloEBNF
import XCTest

/// The EBNF source code for a grammar.
typealias GrammarSource = (text: Substring, sourceFilePath: String, startLine: Int)

/// Called with a multiline string immediately following the open parenthesis (`source("""`),
/// returns that string (sliced), the path to the file in which the string appears, and the line
/// number of the string's first character.
func source(
  _ text: String, sourceFilePath: String = #filePath, startLine: Int = #line
) -> GrammarSource {
  (text[...], sourceFilePath, startLine + 1)
}

/// Returns the path of the Swift source file containing the caller.
func thisFilePath(f: String = #filePath) -> String { f }

/// Returns the line number of its invocation in Swift source.
func thisLine(l: Int = #line) -> Int { l }

final class EBNFScannerTests: XCTestCase {

  static let sample = source("""
a ::=#/
  b c

b ::= (one of)
  0 1 _ * + ( ) ?

c ::= (token)
  '0b'? d+
  x*

d ::= (regexp)
  [^']

e ::=
  f g

f ::=
  f | g
""")

  static let sampleTokens = EBNF.tokens(
    in: sample.text, onLine: sample.startLine, fromFile: sample.sourceFilePath)

  func testTokens() {
    let expected: [(EBNF.Token.ID, String)] = [
      (.LHS, "a"), (.IS_DEFINED_AS, "::="), (.ILLEGAL_CHARACTER, "#"), (.ILLEGAL_CHARACTER, "/"),
      (.SYMBOL_NAME, "b"), (.SYMBOL_NAME, "c"), (.EOL, "\n"),

      (.LHS, "b"), (.IS_DEFINED_AS, "::="), (.ONE_OF_KIND, "(one of)"),
      (.LITERAL, "0"), (.LITERAL, "1"), (.LITERAL, "_"), (.LITERAL, "*"), (.LITERAL, "+"), (.LITERAL, "("), (.LITERAL, ")"), (.LITERAL, "?"), // (.EOL, "\n"),

      (.LHS, "c"), (.IS_DEFINED_AS, "::="), (.TOKEN_KIND, "(token)"),
      (.QUOTED_LITERAL, "'0b'"), (.QUESTION, "?"), (.SYMBOL_NAME, "d"), (.PLUS, "+"), (.EOL, "\n"),
      (.SYMBOL_NAME, "x"), (.STAR, "*"), (.EOL, "\n"),

      (.LHS, "d"), (.IS_DEFINED_AS, "::="), (.REGEXP_KIND, "(regexp)"),
      (.REGEXP, "[^']"), (.EOL, "\n"),

      (.LHS, "e"), (.IS_DEFINED_AS, "::="),
      (.SYMBOL_NAME, "f"), (.SYMBOL_NAME, "g"), (.EOL, "\n"),

      (.LHS, "f"), (.IS_DEFINED_AS, "::="),
      (.SYMBOL_NAME, "f"), (.OR, "|"), (.SYMBOL_NAME, "g"), (.EOL, ""),
    ]

    XCTAssertEqual(Self.sampleTokens.count, expected.count)
    for (t, x) in zip(Self.sampleTokens, expected) {
      XCTAssertEqual(t.id, x.0, "\(t)")
      XCTAssertEqual(t.text, x.1, "\(t)")
    }
  }

  func testWhitespaceSensitivity() {
    let input1 = source("""
  a::= # /
b   c

b::=(one of)
0 1   _ * + ( ) ?

c::=(token)
'0b'?d+
x   *

    d::=(regexp)
  [^']

e::=
f          g

f::=
f|g
""")

    let tokens1 = EBNF.tokens(
      in: input1.text, onLine: input1.startLine, fromFile: input1.sourceFilePath)
    XCTAssertEqual(Self.sampleTokens.count, tokens1.count)

    for (x, y) in zip(Self.sampleTokens, tokens1) {
      XCTAssertEqual(x, y)
    }
  }

  func testTokenPositions() {
    let input = source("""
a ::=
  b c
""")
    // Intentionally lying about the start line.
    let tokens = EBNF.tokens(in: input.text, onLine: 1, fromFile: input.sourceFilePath)
    XCTAssert(tokens.allSatisfy { $0.position.file.url == URL(fileURLWithPath: thisFilePath()) })
    XCTAssertEqual(tokens[0].position.lineAndColumn, .init((1, 1)) ..< .init((1, 2)))
    XCTAssertEqual(tokens[1].position.lineAndColumn, .init((1, 3)) ..< .init((1, 6)))
    XCTAssertEqual(tokens[2].position.lineAndColumn, .init((2, 3)) ..< .init((2, 4)))
    XCTAssertEqual(tokens[3].position.lineAndColumn, .init((2, 5)) ..< .init((2, 6)))
  }
}

struct LineAndColumn: Comparable {
  let line, column: Int

  init(_ x: (line: Int, column: Int)) {
    line = x.line
    column = x.column
  }

  static func < (l: Self, r: Self) -> Bool {
    (l.line, l.column) < (r.line, r.column)
  }
}

extension SourceRange {

  var lineAndColumn:  Range<LineAndColumn> {
    .init(file.position(startIndex).lineAndColumn) ..< .init( file.position(endIndex).lineAndColumn)
  }

}
