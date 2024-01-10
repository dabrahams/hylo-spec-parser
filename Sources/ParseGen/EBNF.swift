import CitronLexerModule
import Utils

/// A Namespace for definitions related to our grammar specification syntax.
public enum EBNF {

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
  public struct Symbol: EBNFNode {

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
    public var position: SourceRegion { position_.value }

    public func dumped(level: Int) -> String { name }
    /// A possible generated symbol name for this node in a BNF grammar
    public var bnfSymbolName: String { name }

  }

  /// The AST representation of a list of EBNF rules.
  ///
  /// Corresponds to `rule_list` in the EBNF grammar syntax.
  public typealias DefinitionList = [Definition]

  /// The AST representation of an EBNF rule.
  ///
  /// Corresponds to `rule` in the EBNF grammar syntax.
  public struct Definition: EBNFNode {

    /// How the particular rule is to be interpreted.
    enum Kind {

      /// A traditional EBNF rule with no special interpretation applied.
      case plain

      /// A nonrecursive rule that describes (part of) a terminal symbol.
      ///
      /// Whitespace is not implicitly recognized between elements of a `(token)` rule.
      ///
      /// - For example:
      ///   ```
      ///   octal-literal ::= (token)
      ///     '0o' octal-digit+
      ///   ```
      ///   In this case, `octal-digit` might itself be a `(token)` rule.
      case token

      /// A rule that recognizes one of a fixed number of literal strings.
      /// Whitespace is not implicitly recognized between elements of a `(token)` rule.
      ///
      /// - For example:
      ///   ```
      ///   method-introducer ::= (one of)
      ///     let sink inout
      ///   ```
      case oneOf

      /// A rule that recognizes strings matching an [ICU regular
      /// expression](https://unicode-org.github.io/icu/userguide/strings/regexp.html).
      ///
      /// - For example:
      ///   ```
      ///   bq-char ::= (regexp)
      ///     [^`\x0a\x0d]
      ///   ```
      case regexp

      /// A traditional EBNF rule, except that if there is a newline between RHS elements of any
      /// top-level alternative, recognition fails.
      ///
      /// - For example:
      ///   ```
      ///   inout-expr ::= (no-newline)
      ///     '&' expr
      ///   ```
      ///   In this case, horizontal whitespace would be allowed between the ampersand and the
      ///   string matching `expr`, but no vertical whitespace.
      case noNewline

      /// A traditional EBNF rule, except that implicit whitespace skipping is disabled between RHS
      /// elements of any top-level alternative
      ///
      /// - For example:
      ///   ```
      ///   inout-expr ::= (no-implicit-whitespace)
      ///     '&' horizontal-space? expr
      ///
      ///   horizontal-space ::= (regexp)
      ///     \h
      ///   ```
      ///   In this case, horizontal whitespace matching the given regular expression would be
      ///   allowed between the ampersand and the string matching `expr`, but no other whitespace
      ///   would be recognized there.
      case noImplicitWhitespace
    }

    /// How this rule should be interpreted.
    let kind: Kind

    /// The symbol recognized by this compound rule.
    let lhs: Symbol

    /// The list of right-hand-side alternatives that derive `lhs`.
    let alternatives: AlternativeList

    /// A possible generated symbol name for this node in a BNF grammar
    public var bnfSymbolName: String { dump }
  }

  /// The AST representation of a list of EBNF rule RHS alternatives.
  ///
  /// Corresponds to `alt_list` in the EBNF grammar syntax.
  public typealias AlternativeList = [Alternative]

  /// The AST representation of an EBNF rule top-level RHS alternative.
  ///
  /// Corresponds to `alt` in the EBNF grammar syntax.
  public typealias Alternative = TermList

  /// The AST representation of an EBNF rule RHS alternative.
  ///
  /// Corresponds to `term_list` in the EBNF grammar syntax.
  public typealias TermList = [Term]

  /// The AST representation of an element of an EBNF rule RHS alternative.
  ///
  /// Corresponds to `term` in the EBNF grammar syntax.
  public enum Term: EBNFNode {

    /// A parenthesized group.
    case group(AlternativeList)

    /// A bare grammar symbol.
    case symbol(Symbol)

    /// A literal string to be recognized (found at `position` in the grammar source).
    case literal(String, position: Incidental<SourceRegion>)

    /// An [ICU regular expression](https://unicode-org.github.io/icu/userguide/strings/regexp.html)
    /// to be matched, (found at `position` in the grammar source).
    case regexp(String, position: Incidental<SourceRegion>)

    /// A term decorated with a `*`, `+`, or `?` quantifier, (found at `position` in the grammar
    /// source).
    indirect case quantified(Term, Character, position: Incidental<SourceRegion>)
  }
}

extension EBNF.Token: CustomStringConvertible {

  public var description: String {
    "Token(.\(id), \(String(reflecting: text)), at: \(String(reflecting: position)))"
  }

}

extension EBNF.Symbol: CustomStringConvertible {

  public var description: String {
    "Symbol(\(String(reflecting: name)), at: \(String(reflecting: position)))"
  }

}



/// A node in the AST of an EBNF grammar description.
public protocol EBNFNode: Hashable {
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
  var dump: String { self.dumped(level: 1) }

}

/// An array of `EBNFNode`s can itself be used as an `EBNFNode`.
extension Array: EBNFNode where Element: EBNFNode {

  public var position: SourceRegion {
    first != nil ? first!.position...last!.position : .empty
  }

  public func dumped(level: Int) -> String {
    self.lazy.map { $0.dumped(level: level + 1) }
      .joined(separator: Self.dumpSeparator(level: level))
  }

  /// Returns the dump text that appears between element dumps.
  private static func dumpSeparator(level: Int) -> String {
    return Element.self == EBNF.Definition.self ? "\n\n" // top level definitions
      : Element.self == EBNF.Alternative.self ? (level == 0 ? "\n  " : " | ") // alternatives
      : " " // terms
  }

  /// A possible generated symbol name for this node in a BNF grammar
  public var bnfSymbolName: String { count > 1 ? "`\(dump)`" : dump }
}

/// An optional `EBNFNode` can itself be used as an `EBNFNode` (representing quantification with
/// `?`).
extension Optional: EBNFNode where Wrapped: EBNFNode {

  public var position: SourceRegion {
    self?.position ?? .empty
  }

  public func dumped(level: Int) -> String { self?.dumped(level: level + 1) ?? "" }

  /// A possible generated symbol name for this node in a BNF grammar
  public var bnfSymbolName: String { "`\(dump)`" }

}

extension EBNF.Definition {

  public var position: SourceRegion { lhs.position...alternatives.position }

  public func dumped(level: Int) -> String {
    let k = [.oneOf: " (one of)", .token: " (token)", .regexp: " (regexp)"][kind]

    return """
    \(position): note: rule
    \(lhs.dump) ::=\(k ?? "")
      \(alternatives.dump)
    """
  }

}

public extension EBNF.Term {

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
