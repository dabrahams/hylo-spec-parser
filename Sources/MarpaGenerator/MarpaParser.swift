import CitronLexerModule
import Marpa
import ParseGen

/// A parser implemented by using Marpa for a language described by an EBNF grammar.
public struct MarpaParser {

  /// Marpa's representation of an equivalent BNF grammar to the EBNF grammar being recognized.
  let grammar: Marpa.Grammar

  /// The base Marpa parser, built from `grammar`.
  let recognizer: Marpa.Recognizer

  /// A symbol outside the input grammar that is generated when no other token can be recognized.
  let unrecognizedCharacterToken: Marpa.Symbol

  /// A recognizer for the tokens of the input grammar.
  let scanner: CitronLexerModule.Scanner<Marpa.Symbol>

  /// A mapping from Marpa `Symbol` to a name from the input grammar (or to a synthesized name if
  /// the symbol was synthesized in EBNF-to-BNF conversion).
  let symbolName: (Marpa.Symbol) -> String

  /// A mapping from Marp `Rule` to a corresponding source region in the input EBNF grammar.
  let ruleLocation: (Marpa.Rule) -> SourceRegion

  /// Creates an instance with the given property values.
  init(
    grammar: Marpa.Grammar,
    unrecognizedCharacterToken: Marpa.Symbol,
    scanner: Scanner<Marpa.Symbol>,
    symbolName: @escaping (Marpa.Symbol) -> String,
    ruleLocation: @escaping (Marpa.Rule) -> SourceRegion
  ) {
    (self.grammar, self.unrecognizedCharacterToken, self.scanner, self.symbolName, self.ruleLocation)
      = (grammar, unrecognizedCharacterToken, scanner, symbolName, ruleLocation)
    recognizer = Recognizer(grammar)
  }

  /// Prints the Marpa grammar with its parts mapped to the EBNF source that generated them.
  ///
  /// The output format complies with the GNU diagnostic standard.
  func dumpGrammar() {
    for r in grammar.rules {
      print("\(ruleLocation(r)): note:", description(r))
    }
  }

  /// Returns a human-readable description of `r` (with a dot marker before the `nth` RHS symbol if
  /// `dotPosition != nil`).
  func description(_ r: Marpa.Rule, dotPosition: Int? = nil) -> String {
    let lhsName = symbolName(grammar.lhs(r))
    let rhsNames = grammar.rhs(r).lazy.map { s in symbolName(s) }
    guard let n = dotPosition else {
      return "\(lhsName) -> \(rhsNames.joined(separator: " "))"
    }
    let dottedRHS = rhsNames.prefix(n) + ["•"] + rhsNames.dropFirst(n)
    return "\(lhsName) -> \(dottedRHS.joined(separator: " "))"
  }

  /// Returns diagnostic notes describing the parser's state at each position in `text`, which was
  /// extracted from `sourceFile` starting at `startPosition`.
  ///
  /// - Precondition: `recognize` was already called on `text`.
  func progressReport(
    text: Substring,
    startingAt startPosition: SourcePosition = .init(line: 1, column: 1),
    inFile sourceFile: String
  ) -> [EBNFError.Note] {
    let diagnosticOffset: SourcePosition.Offset
      = (line: startPosition.line - 1, column: startPosition.column - 1)

    let tokens = scanner.tokens(
      in: String(text), fromFile: sourceFile, unrecognizedCharacter: unrecognizedCharacterToken)

    var r: [EBNFError.Note] = []

    for (e, (t, s, position)) in tokens.enumerated() {
      r.append(
        EBNFError.Note(
          "------------------- token \(e): '\(s)' (\(symbolName(t))) -------------------",
          site: position + diagnosticOffset))

      r.append(
        contentsOf: recognizer.progress(at: EarleySet(id: UInt32(e)))
          .lazy.map { rule, origin, n in
            EBNFError.Note(
              "\(description(rule, dotPosition: n)) (\(origin.id))",
              site: ruleLocation(rule))
          })
    }
    return r
  }

  /// A parse tree resulting from a successful recognition.
  struct Tree {
    /// The Marpa bottom-up `.rule` evaluation step that produces this node from its children.
    let step: Evaluation.Step

    /// The child nodes.
    let children: [Tree]

    init(_ e: Evaluation) {
      // While Marpa calls this thing a stack, it's really used like an array and the docs don't say
      // how indices are allocated, so we'll use a dictionary instead to be safe.
      var stack: [UInt32: Tree] = [:]

      for s in e {
        // If it's a `.rule` step, it's telling us where in the stack to find the children of a
        // node we'll create as part of this evaluation step
        let children: [Tree] = s.rule.map {
          r in r.input.map { i in stack[i]! }
        } ?? []
        // Create the new tree node.
        stack[s.output] = Tree(step: s, children: children)
      }

      // The final reduction always goes into the zeroth element.
      self = stack[0]!
    }

    /// An instance with the given properties.
    private init(step: Evaluation.Step, children: [Tree]) {
      self.step = step
      self.children = children
    }
  }

  /// Returns diagnostic notes describing any errors, and if the parse was successful, the parse
  /// trees derived from `text`, which was extracted from `sourceFile` starting at `startPosition`.
  public func recognize(
    _ text: Substring,
    startingAt startPosition: SourcePosition.Offset = (line: 0, column: 0),
    inFile sourceFile: String
  ) -> EBNFErrorLog {
    var errors: EBNFErrorLog = []

    let tokens = scanner.tokens(
      in: String(text), fromFile: sourceFile, unrecognizedCharacter: unrecognizedCharacterToken)

    recognizer.startInput()

    var esRegions: [SourceRegion] = []
    for (t, s, p) in tokens {
      esRegions.append(p + startPosition)

      guard let err = recognizer.read(t) else {
        recognizer.advanceEarleme()
        continue
      }

      switch err {
      case .unexpectedToken:
        let expected = recognizer.expectedTerminals.lazy.map { t in symbolName(t) }
          .joined(separator: ", ")

        errors.insert(
          EBNFError(
            "\(err) \(symbolName(t)): '\(s)'", at: esRegions.last!,
            notes: [.init("expected one of: " + expected, site: esRegions.last!)]))

      default:
        errors.insert(EBNFError("\(err)", at: esRegions.last!))
      }
      break
    }
    if !errors.isEmpty { return errors }

    guard let b = Bocage(recognizer) else {
      errors.insert(EBNFError("No parse", at: esRegions.last!))
      return errors
    }

    // Deal with the final earley set.
    let l = esRegions.last!
    esRegions.append(SourceRegion(fileName: l.fileName, l.span.upperBound..<l.span.upperBound))
    let inputRegion = esRegions.first!...esRegions.last!
    var trees: [Tree] = []
    for (n, e) in Order(b, highRankOnly: false).enumerated() {
      trees.append(Tree(e))
      if n == 1 { break }
    }
    var notes: [EBNFError.Note] = []
    for t in trees {
      appendNotes(showing: t, to: &notes)
    }

    if trees.count != 1 {
      errors.insert(
        .init(trees.count > 1 ? "Ambiguous parse" : "No parse", at: inputRegion, notes: notes))
    }

    func appendNotes(
      showing t: Tree,
      to notes: inout [EBNFError.Note],
      depth: Int = 0
    ) {
      let s = t.step, l = s.sourceRange
      let indent = repeatElement("  ", count: depth).joined()
      let description = s.symbol != nil
        ? symbolName(s.symbol!.0) + (s.symbol!.tokenValue == nil ? " (null)" : "")
        : "(" + description(s.rule!.0)
      let location: SourceRegion
      let start = esRegions[Int(l.lowerBound.id)]
      if l.isEmpty {
        location = SourceRegion(fileName: sourceFile, start.span.lowerBound..<start.span.lowerBound)
      }
      else {
        location = start...esRegions[Int(l.upperBound.id) - 1]
      }
      notes.append(.init("\t\(indent)\(description)", site: location))

      for child in t.children {
        appendNotes(showing: child, to: &notes, depth: depth + 1)
      }
      if s.rule != nil { notes[notes.count - 1].message += ")" }
    }

    return errors
  }
}
