import Foundation
import Utils

/// A Hylo source file, a synthesized fragment of Hylo source, or a fragment Hylo source embedded
/// in a Swift string literal.
public final class SourceFile {

  /// A position in the source text.
  public typealias Index = String.Index

  /// The contents of the source file.
  public let text: Substring

  /// The URL of the source file.
  public let url: URL

  /// The start position of each line.
  private let lineStarts: [Index]

  /// Creates an instance representing the file at `filePath`.
  public init(contentsOf filePath: URL) throws {
    text = try String(contentsOf: filePath)[...]
    url = filePath
    lineStarts = text.lineBoundaries()
  }

  public static let none = SourceFile(url: URL(string: "none://")!, text: "")

  /// Creates an instance with the given properties; `self.lineStarts` will be computed if
  /// lineStarts is `nil`.
  private init(url: URL, lineStarts: [Index]? = nil, text: Substring) {
    self.url = url
    self.text = text
    self.lineStarts = lineStarts ?? text.lineBoundaries()
  }

  public convenience init(sourceText: Substring, onLine startLine: Int, fromFile sourcePath: String) {
    let l = sourceText.lineBoundaries()
    self.init(
      url: URL(fileURLWithPath: sourcePath),
      lineStarts: Array(repeating: l.first!, count: startLine - 1) + l, text: sourceText)
  }

  /// Creates an instance for the `text` given by a multiline string literal in the given
  /// `swiftFile`, the literal's textual content (the line after the opening quotes) being
  /// startLine.
  ///
  /// The text of the instance will literally be what's in the Swift file, including its
  /// indentation and any embedded special characters, even if the literal itself is not a raw
  /// literal or has had indentation stripped by the Swift compiler.
  fileprivate convenience init(
    diagnosableLiteral text: String, swiftFile: String, startLine: Int
  ) throws {
    let wholeFile = try SourceFile(contentsOf: URL(fileURLWithPath: swiftFile))
    let endLine = startLine + text.lazy.filter(\.isNewline).count
    self.init(
      url: URL(string: "\(wholeFile.url.absoluteString)#L\(startLine)-L\(endLine)")!,
      lineStarts: wholeFile.lineStarts,
      text: wholeFile.text[
        wholeFile.index(line: startLine, column: 1)
          ..< wholeFile.index(line: endLine + 1, column: 1)])
  }

  /// Creates an instance representing the at `filePath`.
  public convenience init<S: StringProtocol>(path filePath: S) throws {
    try self.init(contentsOf: URL(fileURLWithPath: String(filePath)))
  }

  /// Creates a synthetic source file with the specified contents and base name.
  public convenience init(synthesizedText text: String, named baseName: String = UUID().uuidString) {
    self.init(url: URL(string: "synthesized://\(baseName)")!, text: text[...])
  }

  /// The name of the source file, sans path qualification or extension.
  public var baseName: String {
    if isSynthesized {
      return url.host!
    } else {
      return url.deletingPathExtension().lastPathComponent
    }
  }

  /// `true` if `self` is synthesized.
  public var isSynthesized: Bool {
    url.scheme == "synthesized"
  }

  /// The number of lines in the file.
  public var lineCount: Int { lineStarts.count }

  /// A range covering the whole contents of this instance.
  public var wholeRange: SourceRange {
    range(text.startIndex ..< text.endIndex)
  }

  /// Returns a range starting and ending at `index`.
  public func emptyRange(at index: String.Index) -> SourceRange {
    range(index ..< index)
  }

  /// Returns the contents of the file in the specified range.
  ///
  /// - Requires: The bounds of `range` are valid positions in `self`.
  public subscript(_ range: SourceRange) -> Substring {
    precondition(range.file.url == url, "invalid range")
    return text[range.startIndex ..< range.endIndex]
  }

  /// Returns the position corresponding to `i` in `text`.
  ///
  /// - Requires: `i` is a valid index in `text`.
  public func position(_ i: Index) -> SourcePosition {
    SourcePosition(i, in: self)
  }

  /// Returns the position immediately before `p`.
  ///
  /// - Requires: `p` is a valid position in `self`.
  public func position(before p: SourcePosition) -> SourcePosition {
    SourcePosition(text.index(before: p.index), in: self)
  }

  /// Returns the position corresponding to the given 1-based line and column indices.
  ///
  /// - Requires: the line and column exist in `self`.
  public func position(line: Int, column: Int) -> SourcePosition {
    SourcePosition(line: line, column: column, in: self)
  }

  /// Returns the region of `self` corresponding to `r`.
  ///
  /// - Requires: `r` is a valid range in `self`.
  public func range(_ r: Range<Index>) -> SourceRange {
    SourceRange(r, in: self)
  }

  /// Returns the 1-based line and column numbers corresponding to `i`.
  ///
  /// - Requires: `i` is a valid index in `contents`.
  ///
  /// - Complexity: O(log N) + O(C) where N is the number of lines in `self` and C is the returned
  ///   column number.
  func lineAndColumn(_ i: Index) -> (line: Int, column: Int) {
    let containingLine0Based = lineStarts.partitionPoint(where: { $0 > i }) - 1
    let column0Based = text[lineStarts[containingLine0Based] ..< i].count
    return (containingLine0Based + 1, column0Based + 1)
  }

  /// Returns the index in `text` corresponding to `line` and `column`.
  ///
  /// - Requires: `line` and `column` describe a valid position in `self`.
  func index(line: Int, column: Int) -> Index {
    return text.index(lineStarts[line - 1], offsetBy: column - 1)
  }

}

extension SourceFile {

  /// Returns a SourceFile containing the given text of a multiline string literal, such that
  /// diagnostics produced in processing that file will point back to the original Swift source.
  ///
  /// The text of the result will literally be what's in the Swift file, including its
  /// indentation and any embedded special characters, even if the literal itself is not a raw
  /// literal or has had indentation stripped by the Swift compiler. It is assumed that the first
  /// line of the string literal's content is two lines below `invocationLine`, which is consistent
  /// with this project's formatting standard.
  ///
  /// - Warning:
  ///   - Do not insert a blank line between the opening parenthesis of the invocation and the
  ///     opening quotation mark.
  ///   - Only use this function with multiline string literals.
  ///   - Serialization of the result is not supported.
  public static func diagnosableLiteral(
    _ multilineLiteralText: String, swiftFile: String = #filePath, invocationLine: Int = #line
  ) -> SourceFile {
    try! .init(
      diagnosableLiteral: multilineLiteralText, swiftFile: swiftFile, startLine: invocationLine + 2)
  }

}

extension SourceFile: ExpressibleByStringLiteral {

  public convenience init(stringLiteral text: String) {
    self.init(synthesizedText: text)
  }

}

extension SourceFile: Hashable {

  public func hash(into hasher: inout Hasher) {
    hasher.combine(url)
  }

  public static func == (lhs: SourceFile, rhs: SourceFile) -> Bool {
    return lhs.url == rhs.url
  }

}

extension SourceFile: CustomStringConvertible {

  public var description: String { "SourceFile(\(url))" }

}

/// Given a collection of file and directory paths as specified on the hc command line, returns
/// the actual source files to process.
///
/// Paths of files in `sourcePaths` are unconditionally treated as Hylo source files. Paths of
/// directories are recursively searched for `.hylo` files, which are considered Hylo source files;
/// all others are treated as non-source files and are ignored.
public func sourceFiles<S: Sequence<URL>>(in sourcePaths: S) throws -> [SourceFile] {
  try sourcePaths.flatMap { (p) in
    try p.hasDirectoryPath
      ? sourceFiles(in: p, withExtension: "hylo")
      : [SourceFile(contentsOf: p)]
  }
}

/// Returns the source source files in `directory`.
///
/// `directory` is recursively searched for files with extension `e`; all others are treated as
/// non-source files and are ignored. If `directory` is a filename, the function returns `[]`.
public func sourceFiles(in directory: URL, withExtension e: String) throws -> [SourceFile] {
  let allFiles = FileManager.default.enumerator(
    at: directory,
    includingPropertiesForKeys: [.isRegularFileKey],
    options: [.skipsHiddenFiles, .skipsPackageDescendants])!

  var result: [SourceFile] = []
  for case let f as URL in allFiles where f.pathExtension == e {
    try result.append(SourceFile(contentsOf: f))
  }
  return result
}

extension Collection {
  /// Returns the index of the first element in the collection
  /// that matches the predicate.
  ///
  /// The collection must already be partitioned according to the
  /// predicate, as if `self.partition(by: predicate)` had already
  /// been called.
  ///
  /// - Efficiency: At most log(N) invocations of `predicate`, where
  ///   N is the length of `self`.  At most log(N) index offsetting
  ///   operations if `self` conforms to `RandomAccessCollection`;
  ///   at most N such operations otherwise.
  func partitionPoint(
    where predicate: (Element) throws -> Bool
  ) rethrows -> Index {
    var n = distance(from: startIndex, to: endIndex)
    var l = startIndex

    while n > 0 {
      let half = n / 2
      let mid = index(l, offsetBy: half)
      if try predicate(self[mid]) {
        n = half
      } else {
        l = index(after: mid)
        n -= half + 1
      }
    }
    return l
  }
}

extension StringProtocol {

  /// Returns the indices of the start of each line, in order.
  public func lineBoundaries() -> [Index] {
    var r = [startIndex]
    var remainder = self[...]
    while !remainder.isEmpty, let i = remainder.firstIndex(where: \.isNewline) {
      let j = index(after: i)
      r.append(j)
      remainder = remainder[j...]
    }
    return r
  }

}

extension URL {

  /// The path in the filesystem.
  ///
  /// - Precondition: `self` is a file scheme or file reference URL.
  var fileSystemPath: String {
    self.standardizedFileURL.withUnsafeFileSystemRepresentation { (name: UnsafePointer<CChar>?) in
      FileManager().string(
        withFileSystemRepresentation: name!,
        length: (0...).first(where: { i in name![i] == 0 })!)
    }
  }

}
