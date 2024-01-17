import SourcesAndDiagnostics

/// An error produced when compiling a grammar.
public struct EBNFError: Error, Hashable {

  /// An additional informative note to go with the error message.
  public struct Note: Hashable {

    /// The text of the note
    public var message: String

    /// Where to point in the source code.
    public let site: SourceRange

    /// Creates an instance with the given properties.
    public init(_ message: String, site: SourceRange) {
      self.message = message
      self.site = site
    }

  }

  /// A human-readable description of the problem.
  public let message: String
  /// Where to point in the source code
  public let site: SourceRange
  /// Any additional notes
  public let notes: [Note]

  /// Creates an instance with the given properties.
  public init(_ message: String, at site: SourceRange, notes: [Note] = []) {
    self.message = message
    self.site = site
    self.notes = notes
  }

  public static func == (l: Self, r: Self) -> Bool {
    l.message == r.message && l.site == r.site
    && l.notes.lazy.map(\.message) == r.notes.lazy.map(\.message)
      && l.notes.lazy.map(\.site) == r.notes.lazy.map(\.site)
  }

}

extension EBNFError: CustomStringConvertible {

  /// String representation that, if printed at the beginning of the line,
  /// should be recognized by IDEs.
  public var description: String {
    return (
      ["\(site): error: \(message)"] + notes.enumerated().lazy.map {
        (i, n) in "\(n.site): note(\(i)): \(n.message)"
      }).joined(separator: "\n")
  }

}
#if false
public extension SourcePosition {

  typealias Offset = (line: Int, column: Int)

  /// Returns `l` offset by `r`
  static func + (l: Self, r: Offset) -> Self {
    return .init(line: l.line + r.line, column: l.column + r.column)
  }

  /// Returns `r` offset by `l`
  static func + (l: Offset, r: Self) -> Self {
    return .init(line: l.line + r.line, column: l.column + r.column)
  }

}

public extension SourceRange {

  /// Returns `l` offset by `r`.
  static func + (l: Self, r: SourcePosition.Offset) -> Self {
    return .init(
      fileName: l.fileName, (l.span.lowerBound + r)..<(l.span.upperBound + r))
  }

  /// Returns `r` offset by `l`.
  static func + (l: SourcePosition.Offset, r: Self) -> Self {
    return .init(
      fileName: r.fileName, (r.span.lowerBound + l)..<(r.span.upperBound + l))
  }

}

extension EBNFError {

  /// Returns `l` offset by `r`.
  static func + (l: Self, r: SourcePosition.Offset) -> Self {
    Self(
      l.message, at: l.site + r,
      notes: l.notes.map { .init($0.message, site: $0.site + r) })
  }

  /// Returns `r` offset by `l`.
  static func + (l: SourcePosition.Offset, r: Self) -> Self {
    Self(
      r.message, at: r.site + l,
      notes: r.notes.map { .init($0.message, site: $0.site + l) })
  }

}
#endif

public typealias EBNFErrorLog = Set<EBNFError>

extension EBNFErrorLog: Error {

  // Note: the following method is not simply `description` because Set already has a
  // `CustomStringConvertible` conformance that can't be overridden.  Perhaps make `EBNFErrorlog` a
  // wrapper around a `Set` to solve that.

  /// Returns a string representation suitable for display in an IDE.
  public func report() -> String {
    self.sorted { $0.site.start < $1.site.start }
      .lazy.map { "\($0)" }.joined(separator: "\n")
  }

}
