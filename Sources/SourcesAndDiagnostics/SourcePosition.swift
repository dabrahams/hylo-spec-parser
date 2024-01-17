/// A character boundary in a source file.
public struct SourcePosition: Hashable {

  /// The source file containing the position.
  public let file: SourceFile

  /// The position relative to the source file.
  public let index: String.Index

  /// Creates an instance with the given properties.
  public init(_ index: String.Index, in file: SourceFile) {
    self.file = file
    self.index = index
  }

  /// Creates an instance referring to the given 1-based line and column numbers in `source`.
  ///
  /// - Precondition: `line` and `column` denote a valid position in `source`.
  public init(line: Int, column: Int, in file: SourceFile) {
    self.file = file
    self.index = file.index(line: line, column: column)
  }

  /// The line and column number of this position.
  public var lineAndColumn: (line: Int, column: Int) {
    let r = file.lineAndColumn(index)
    return (r.line, r.column)
  }

  /// Returns a site from `l` to `r`.
  ///
  /// - Requires: `l.file == r.file`
  public static func ..< (l: Self, r: Self) -> SourceRange {
    precondition(l.file == r.file, "incompatible locations")
    return l.file.range(l.index ..< r.index)
  }

}

extension SourcePosition: Comparable {

  public static func < (l: Self, r: Self) -> Bool {
    precondition(l.file == r.file, "incompatible locations")
    return l.index < r.index
  }

}

extension SourcePosition: CustomStringConvertible {

  public var description: String {
    let (line, column) = lineAndColumn
    return "\(file.url.relativePath):\(line):\(column)"
  }

}
