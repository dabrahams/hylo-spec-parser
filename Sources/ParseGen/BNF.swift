import CitronLexerModule

extension Collection {

  /// The sole element, if `count == 1`, or `nil` otherwise.
  var onlyElement: Element? {
    return first.map { x in dropFirst().isEmpty ? x : nil } ?? nil
  }

}

/// Types that can be used to construct a BNF grammar from EBNF.
public protocol BNFBuilder {

  /// A symbol in the constructed BNF.
  associatedtype Symbol: Hashable

  /// Returns a new BNF terminal symbol corresponding to `n`.
  ///
  /// It would typically be a mistake to call this function twice for the same `n`.
  mutating func makeTerminal<N: EBNFNode>(_ n: N) -> Symbol

  /// Returns a new BNF nonterminal symbol corresponding to `n`.
  mutating func makeNonterminal<N: EBNFNode>(_ n: N) -> Symbol

  /// Sets the BNF grammar's start symbol.
  mutating func setStartSymbol(_: Symbol)

  /// Adds a BNF rule corresponding to `source`, reducing the elements of `rhs` to the nonterminal
  /// symbol `lhs`.
  mutating func addRule<RHS: Collection, Source: EBNFNode>(
    reducing rhs: RHS, to lhs: Symbol, source: Source) where RHS.Element == Symbol

}

/// State of the process of converting a Hylo EBNF grammar into an `Output` BNF grammar.
public struct EBNFToBNF<Output: BNFBuilder> {

  /// The target of the conversion.
  ///
  /// - Precondition for reading: `build()` has already been called.
  public private(set) var output: Output

  /// The grammar to be converted.
  private let input: EBNF.Grammar

  /// The inputs's nonterminal symbols
  private let inputNonterminals: Set<EBNF.Symbol>

  /// Mapping from pieces of EBNF AST to Output symbol.
  private var bnfSymbol: [EBNF.Term: Output.Symbol] = [:]

  /// An instance converting `input` into `output`.
  ///
  /// - Precondition: `output` is empty.
  public init(from input: EBNF.Grammar, into output: Output) {
    (self.input, self.output) = (input, output)
    inputNonterminals = input.nonterminals()
  }

  /// Returns the `output` symbol corresponding to `s`.
  ///
  /// - Precondition: `s` was used in the input grammar.
  public func asBNF(_ s: EBNF.Symbol) -> Output.Symbol {
    bnfSymbol[.symbol(s)]!
  }

  /// Returns the `output` symbol corresponding to `l`.
  ///
  /// - Precondition: `l` was used in the input grammar.
  public func asBNF(literal l: String) -> Output.Symbol {
    bnfSymbol[.literal(l, position: .init(.empty))]!
  }

  /// Returns the `output` symbol corresponding to `s`, creating it if necessary.
  private mutating func demandSymbol(_ s: EBNF.Symbol) -> Output.Symbol {
    demandBNFSymbol(.symbol(s))
  }

  /// Prepares `output` to be read.
  ///
  /// - Note: should only be called once.
  public mutating func build() {
    for d in input.definitions {
      if inputNonterminals.contains(d.lhs) {
        for a in d.alternatives {
          buildRule(reducing: a, to: demandBNFSymbol(.symbol(d.lhs)), source: a)
        }
      }
    }
    output.setStartSymbol(demandSymbol(input.start))
  }

  /// Updates `output` with the BNF rule(s) corresponding to a rule deriving the EBNF symbol corresponding
  /// to `lhs` from `rhs`.
  mutating func buildRule<RHS: Collection, Source: EBNFNode>(
    reducing rhs: RHS, to lhs: Output.Symbol, source: Source
  ) where RHS.Element == EBNF.Term {

    buildRule(reducingBNF: rhs.map { t in demandBNFSymbol(t) }, to: lhs, source: source)

  }

  /// Updates `output` with the BNF rule(s) deriving `lhs` from `rhs`.
  mutating func buildRule<RHS: Collection, Source: EBNFNode>(
    reducingBNF rhs: RHS, to lhs: Output.Symbol, source: Source
  ) where RHS.Element == Output.Symbol {
    output.addRule(reducing: rhs, to: lhs, source: source)
  }

  /// Returns a BNF symbol corresponding to `t`, creating it in `output` if necessary.
  mutating func demandBNFSymbol(_ t: EBNF.Term) -> Output.Symbol {
    if let r = bnfSymbol[t] { return r }

    let lhs: Output.Symbol
    defer { bnfSymbol[t] = lhs }

    switch t {
    case .group(let alternatives):
      lhs = output.makeNonterminal(alternatives)
      for rhs in alternatives {
        buildRule(reducing: rhs, to: lhs, source: t)
      }
    case .symbol(let s):
      lhs = inputNonterminals.contains(s) ? output.makeNonterminal(s) : output.makeTerminal(s)
    case .literal, .regexp:
      lhs = output.makeTerminal(t)
    case .quantified(let t1, let q, _):
      lhs = output.makeNonterminal(t)
      if q == "*" || q == "?" {
        buildRule(reducingBNF: EmptyCollection(), to: lhs, source: t)
      }
      if q == "+" || q == "?" {
        buildRule(reducing: CollectionOfOne(t1), to: lhs, source: t)
      }
      if q == "*" || q == "+" {
        let t2 = demandBNFSymbol(t1)
        buildRule(reducingBNF: [lhs, t2], to: lhs, source: t)
      }
    }
    return lhs
  }

}
