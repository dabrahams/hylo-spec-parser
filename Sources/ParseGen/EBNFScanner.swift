import CitronLexerModule

/// A mapping from single-character token representations to their ID as consumed by the Citron
/// parser.
let tokenID: [Character: EBNF.Token.ID] = [
  "*": .STAR,
  "+": .PLUS,
  "|": .OR,
  "(": .LPAREN,
  ")": .RPAREN,
  "?": .QUESTION
]

/// The textual input stream, tracking its position in a source file.
private struct Input {

  /// The remaining text to be tokenized.
  var tail: Substring

  /// The source line number of the start of `tail`.
  var currentLine: Int

  /// The position of the first character (in the whole input) on `currentLine`.
  var column1: String.Index

  /// An instance for tokenizing `text` starting on `startLine` of a source file.
  init(_ text: Substring, onLine startLine: Int) {
    column1 = text.startIndex
    currentLine = startLine
    tail = text
  }

  /// Consumes any leading whitespace.
  mutating func skipWhitespace() {
    while !tail.isEmpty && tail.first!.isWhitespace { popFirst() }
  }

  /// Consumes any leading whitespace that is not a newline.
  mutating func skipHorizontalSpace() {
    tail = tail.drop { c in c.isWhitespace && !c.isNewline }
  }

  /// Consumes and returns leading non-whitespace, or returns `nil` if there is no leading
  /// whitespace.
  mutating func eatNonWhitespace() -> Substring? {
    let h = tail
    tail = tail.drop { !$0.isWhitespace }
    return h.startIndex == tail.startIndex ? nil : h[..<tail.startIndex]
  }

  /// Consumes and returns a leading symbol name, or returns `nil` if there is no leading symbol.
  mutating func eatSymbolName() -> Substring? {
    guard let c = tail.first, c.isLetter else { return nil }
    let h = tail
    tail = tail.drop { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
    return h[..<tail.startIndex]
  }

  /// Consumes and returns the text of a leading quoted literal, or returns `nil` if there is no
  /// leading quoted literal.
  mutating func eatQuotedLiteral() -> Substring? {
    guard let c = tail.first, c == "'" else { return nil }
    var s = self
    s.popFirst()
    while let c = s.first, c != "'" {
      if c == "\\" { s.popFirst() }
      s.popFirst()
    }
    if s.popFirst() != "'" { return nil }
    defer { self = s }
    return tail[..<s.tail.startIndex]
  }

  /// Consumes and returns leading text identical to `target`, or returns `nil` if no such leading
  /// text exists.
  mutating func eat(_ target: String) -> Substring? {
    var t = target[...]
    var s = self
    while !t.isEmpty && t.first == s.tail.first {
      t = t.dropFirst()
      s.popFirst()
    }
    if !t.isEmpty { return nil }
    defer { self = s }
    return tail[..<s.tail.startIndex]
  }

  /// Consumes and returns the leading non-newline text (or returns "" if there is none).
  mutating func eatRestOfLine() -> Substring {
    let h = tail
    tail = tail.drop { !$0.isNewline }
    return h[..<tail.startIndex]
  }

  /// Consumes and returns the next character, or returns nil if there is no next character.
  @discardableResult
  mutating func popFirst() -> Character? {
    guard let r = tail.popFirst() else { return nil }
    if r.isNewline {
      currentLine += 1
      column1 = tail.startIndex
    }
    return r
  }

  /// True iff all the text was consumed.
  var isEmpty: Bool { tail.isEmpty }

  /// The next character, or `nil` if there is no next character.
  var first: Character? { tail.first }

  /// True iff the next character is a newline.
  var atEOL: Bool { isEmpty || tail.first!.isNewline }
}

extension EBNF {

  /// Returns the EBNF tokens for `sourceText`, starting on `startLine` of the file at `sourcePath`.
  static func tokens(
    in sourceText: Substring, onLine startLine: Int, fromFile sourcePath: String
  ) -> [Token] {
    var output: [Token] = []
    var input = Input(sourceText, onLine: startLine)

    func token(_ kind: EBNF.Token.ID, _ text: Substring) {
      let startColumn = sourceText.distance(from: input.column1, to: text.startIndex) + 1

      let start = SourcePosition(line: input.currentLine, column: startColumn)
      let end = SourcePosition(line: input.currentLine, column: startColumn + text.count)

      output.append(Token(kind, String(text), at: SourceRegion(fileName: sourcePath, start..<end)))
    }

    func illegalToken() {
      characterToken(.ILLEGAL_CHARACTER)
    }

    func characterToken(_ id: EBNF.Token.ID) {
      token(id, input.tail.prefix(1))
      input.popFirst()
    }

    while !input.isEmpty {
      input.skipWhitespace()

      var currentDefinitionKind: Definition.Kind = .plain

      while !input.atEOL {
        if let s = input.eatSymbolName() {
          token(.LHS, s)
        }
        else if let t = input.eat("::=") {
          token(.IS_DEFINED_AS, t)
        }
        else if let t = input.eat("(one of)") {
          token(.ONE_OF_KIND, t)
          currentDefinitionKind = .oneOf
        }
        else if let t = input.eat("(token)") {
          token(.TOKEN_KIND, t)
          currentDefinitionKind = .token
        }
        else if let t = input.eat("(regexp)") {
          token(.REGEXP_KIND, t)
          currentDefinitionKind = .regexp
        }
        else if input.isEmpty {
          return output
        }
        else {
          illegalToken()
        }
        input.skipHorizontalSpace()
      }
      input.popFirst(); input.skipHorizontalSpace()

      while !input.atEOL {
        // Process one line with its trailing newline and any leading space on the next line
        switch currentDefinitionKind {
        case .oneOf:
          while let x = input.eatNonWhitespace() {
            token(.LITERAL, x)
            input.skipHorizontalSpace()
          }

        case .plain, .token:
          while !input.atEOL {
            if let t = input.eatQuotedLiteral() {
              token(.QUOTED_LITERAL, t)
            }
            else if let t = input.eatSymbolName() {
              token(.SYMBOL_NAME, t)
            }
            else if let c = input.first, let k = tokenID[c] {
              characterToken(k)
            }
            else { illegalToken() }
            input.skipHorizontalSpace()
          }

        case .regexp:
          let l = input.eatRestOfLine()
          token(.REGEXP, l.strippingWhitespace())
        }
        if currentDefinitionKind == .oneOf { input.popFirst() }
        else { characterToken(.EOL); }

        input.skipHorizontalSpace()
      }
    }

    return output
  }

}
