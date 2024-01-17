import Foundation

/// A half-open range of positions in a source file.
public struct SourceRange: Hashable {

  /// The source file containing the locations.
  public let file: SourceFile

  /// The part of `file` covered by `self`.
  public let indices: Range<String.Index>

  /// The start index of the range.
  public var start: String.Index { indices.lowerBound }

  /// The end index of the range.
  public var end: String.Index { indices.upperBound }

  private static let empty = ""
  public static let none = SourceRange(empty.startIndex..<empty.endIndex, in: .none)

  /// Creates an instance with the given properties.
  public init(_ indices: Range<String.Index>, in file: SourceFile) {
    self.file = file
    self.indices = indices
  }

  /// Returns whether `self` contains the given location.
  public func contains(_ l: SourcePosition) -> Bool {
    (l.file == file) && indices.contains(l.index)
  }

  /// Returns the first source location in this range.
  public func first() -> SourcePosition {
    file.position(start)
  }

  /// Returns the last source location in this range, unless the range is empty.
  public func last() -> SourcePosition? {
    indices.isEmpty ? nil : file.position(text.dropLast().endIndex)
  }

  /// Returns a copy of `self` with the end increased (if necessary) to `newEnd`.
  public func extended(upTo newEnd: String.Index) -> SourceRange {
    precondition(newEnd >= end)
    return file.range(start ..< newEnd)
  }

  /// Returns a copy of `self` extended to cover `other`.
  public func extended(toCover other: SourceRange) -> SourceRange {
    precondition(file == other.file, "incompatible ranges")
    return file.range(Swift.min(start, other.start) ..< Swift.max(end, other.end))
  }

  /// Increases (if necessary) the end of `self` so that it equals `newEnd`.
  public mutating func extend(upTo newEnd: String.Index) {
    self = self.extended(upTo: newEnd)
  }

  /// Returns a copy of `self` extended to cover `other`.
  public mutating func extend(toCover other: SourceRange) {
    self = self.extended(toCover: other)
  }

  /// The source text contained in this range.
  public var text: Substring {
    file.text[indices]
  }

  /// Creates an empty range that starts and end at `p`.
  public static func empty(at p: SourcePosition) -> Self {
    SourceRange(p.index ..< p.index, in: p.file)
  }

  /// Creates an empty range at the end of `other`.
  public static func empty(atEndOf other: SourceRange) -> Self {
    SourceRange(other.end ..< other.end, in: other.file)
  }

}

extension SourceRange: CustomStringConvertible {

  /// A textual representation per the
  /// [Gnu-standard](https://www.gnu.org/prep/standards/html_node/Errors.html).
  public var gnuStandardText: String {
    let start = first().lineAndColumn
    let head = "\(file.url.relativePath):\(start.line).\(start.column)"
    if self.start == self.end { return head }

    let end = file.position(end).lineAndColumn
    if end.line == start.line {
      return head + "-\(end.column)"
    }
    return head + "-\(end.line):\(end.column)"
  }

  public var description: String { gnuStandardText }

}

extension SourceRange {

  public static func ... (l: Self, r: Self) -> Self {
    l.extended(toCover: r)
  }

}
