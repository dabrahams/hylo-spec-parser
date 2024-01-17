extension EBNF {

  /// A complete EBNF language syntax description.
  public struct Grammar {

    /// The language's syntax rules.
    public let definitions: [Definition]

    /// The symbol whose complete recognition over the entire input represents a successful parse.
    public let start: Symbol

    /// A mapping from each symbol to its definition.
    public let definitionsByLHS: [EBNF.Symbol: Definition]
  }

}

extension EBNF.Grammar {

  /// An instance with rules given by `ast` and start symbol named `startName`.
  ///
  /// Throws diagnostics if rules of the grammar are ill-formed, e.g.:
  /// - If any symbols are used that don't appear on the LHS of a rule.
  /// - If any symbols are defined that can't participate in a parse of the start symbol.
  /// - If any `(token)` rules are recursive.
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
      if let x = definitionsByLHS[.init(name, at: ast.position)] { return x.lhs }
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
