extension EBNF {

  public struct Grammar {
    public let definitions: [Definition]
    public let definitionsByLHS: [EBNF.Symbol: Definition]
    public let start: Symbol
  }

}

extension EBNF.Grammar {
  init(_ ast: [EBNF.Definition], start startName: String) throws {
    var errors: EBNFErrorLog = []
    definitions = ast
    definitionsByLHS = Dictionary(ast.lazy.map {(key: $0.lhs, value: $0)}) { a, b in
      errors.insert(
        EBNFError(
        "Duplicate symbol definition", at: b.position,
        notes: [.init("First definition", site: a.position)]))
      return a
    }

    let lhsSymbol: (_: String) throws -> EBNF.Symbol = { [definitionsByLHS] name in
      if let x = definitionsByLHS[.init(name, at: .empty)] { return x.lhs }
      errors.insert(
        EBNFError("Symbol \(name) not defined\n\(ast)", at: ast.position))
      throw errors
    }
    start = try lhsSymbol(startName)

    checkAllSymbolsDefined(into: &errors)
    checkAllSymbolsReachable(into: &errors)
    checkNoRecursiveTokens(into: &errors)
    if !errors.isEmpty { throw errors }
  }
}
