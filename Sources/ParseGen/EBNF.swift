import CitronLexerModule
import Utils

/// A Namespace for definitions related to our grammar specification syntax.
enum EBNF {
  typealias Error = EBNFError

  /// A terminal such as `::=` in the grammar specification syntax.
  struct Token: Equatable {

    /// The kind of token; all that matters to the EBNF syntax parser.
    typealias ID = EBNFParser.CitronTokenCode

    /// Creates an instance with the given properties.
    ///
    /// - Note: the position of a token is not considered to be part of its value.
    init(_ id: ID, _ content: String, at position: SourceRegion) {
      self.id = id
      self.text = content
      self.position_ = .init(position)
    }

    /// The kind of token; all that matters to the EBNF syntax parser.
    let id: ID

    /// The source text of the token.
    let text: String

    /// The position in the grammar source.
    let position_: Incidental<SourceRegion>

    /// The position in the grammar source (incidental to the value).
    var position: SourceRegion { position_.value }
  }

  /// A name in the grammar specification syntax.
  struct Symbol: EBNFNode {

    /// Creates an instance from `t`, which must have kind `.SYMBOL_NAME` or `.LHS`.
    init(_ t: Token) {
      precondition(t.id == .SYMBOL_NAME || t.id == .LHS)
      self.init(t.text, at: t.position)
    }

    /// Creates an instance with the given properties
    init(_ content: String, at position: SourceRegion) {
      self.name = content
      self.position_ = .init(position)
    }

    /// The text of the name.
    let name: String

    /// The position in the grammar source.
    let position_: Incidental<SourceRegion>

    /// The position in the grammar source (incidental to the value).
    var position: SourceRegion { position_.value }

    func dumped(level: Int) -> String { name }
    /// A possible generated symbol name for this node in a BNF grammar
    var bnfSymbolName: String { name }

  }

  typealias DefinitionList = [Definition]
  struct Definition: EBNFNode {
    enum Kind { case plain, token, oneOf, regexp, noNewline, noImplicitWhitespace }
    let kind: Kind
    let lhs: Symbol
    let alternatives: AlternativeList

    /// A possible generated symbol name for this node in a BNF grammar
    var bnfSymbolName: String { dump }
  }

  typealias AlternativeList = [Alternative]
  typealias Alternative = TermList
  typealias TermList = [Term]

  enum Term: EBNFNode {
    case group(AlternativeList)
    case symbol(Symbol)
    case literal(String, position: Incidental<SourceRegion>)
    case regexp(String, position: Incidental<SourceRegion>)
    indirect case quantified(Term, Character, position: Incidental<SourceRegion>)
  }
}

extension EBNF.Token: CustomStringConvertible {
  var description: String {
    "Token(.\(id), \(String(reflecting: text)), at: \(String(reflecting: position)))"
  }
}

extension EBNF.Symbol: CustomStringConvertible {
  var description: String {
    "Symbol(\(String(reflecting: name)), at: \(String(reflecting: position)))"
  }
}



/// An EBNFNode node.
protocol EBNFNode: Hashable {
  /// The region of source parsed as this node.
  var position: SourceRegion { get }

  /// Returns a string representation in the original syntax, assuming this node appears at the
  /// given `level` of the tree.
  func dumped(level: Int)-> String

  /// A possible generated symbol name for this node in a BNF grammar
  var bnfSymbolName: String { get }
}

extension EBNFNode {
  /// A string representation in the original syntax.
  var dump: String { self.dumped(level: 0) }
}

extension Array: EBNFNode where Element: EBNFNode {
  var position: SourceRegion {
    first != nil ? first!.position...last!.position : .empty
  }

  func dumped(level: Int) -> String {
    self.lazy.map { $0.dumped(level: level + 1) }
      .joined(separator: Self.dumpSeparator(level: level))
  }

  static func dumpSeparator(level: Int) -> String {
    return Element.self == EBNF.Definition.self ? "\n\n"
      : Element.self == EBNF.Alternative.self ? (level == 0 ? "\n  " : " | ")
      : " "
  }

  /// A possible generated symbol name for this node in a BNF grammar
  var bnfSymbolName: String { dump }
}

extension Optional: EBNFNode where Wrapped: EBNFNode {
  var position: SourceRegion {
    self?.position ?? .empty
  }
  func dumped(level: Int) -> String { self?.dumped(level: level + 1) ?? "" }

  /// A possible generated symbol name for this node in a BNF grammar
  var bnfSymbolName: String { "`\(dump)`" }
}

extension EBNF.Definition {
  var position: SourceRegion { lhs.position...alternatives.position }
  func dumped(level: Int) -> String {
    let k = [.oneOf: " (one of)", .token: " (token)", .regexp: " (regexp)"][kind]

    return """
    \(position): note: rule
    \(lhs.dump) ::=\(k ?? "")
      \(alternatives.dump)
    """
  }
}

extension EBNF.Term {
  var position: SourceRegion {
    switch self {
    case .group(let g): return g.position
    case .symbol(let s): return s.position
    case .regexp(_, let p): return p.value
    case .literal(_, let p): return p.value
    case .quantified(_, _, let p): return p.value
    }
  }

  func dumped(level: Int) -> String {
    switch self {
    case .group(let g): return "( \(g.dumped(level: level + 1)) )"
    case .symbol(let s): return s.dumped(level: level)
    case .literal(let s, _):
      return "'\(s.replacingOccurrences(of: "'", with: "\\'"))'"
    case .regexp(let s, _): return "/\(s)/"
    case .quantified(let t, let q, _): return t.dumped(level: level + 1) + String(q)
    }
  }

  var bnfSymbolName: String {
    let s = self.dumped(level: 1)
    switch self {
    case .symbol, .literal, .regexp: return s
    default: return "`\(s)`"
    }
  }
}
