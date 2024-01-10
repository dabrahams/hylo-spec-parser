import XCTest
import CitronLexerModule
@testable import ParseGen

private struct TestBuilder: BNFBuilder {
  typealias Symbol = Int
  var symbolName: [String] = []
  var symbolLocation: [SourceRegion] = []
  var rules: [(lhs: Symbol, rhs: [Symbol])] = []
  var ruleLocation: [SourceRegion] = []
  var startSymbol: Symbol?

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

  func testSimple() throws {
    do {
      let s = source("""
start ::=
  'a'
""")
      let r = try bnf(s)
      print(r.rules)
    }
    catch let e as EBNFErrorLog {
      XCTFail("Unexpected error\n\(e.report())")
    }
  }

}
