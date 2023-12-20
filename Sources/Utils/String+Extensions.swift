import Foundation
import LoftDataStructures_Zip2Collection

extension StringProtocol {
  /// Returns the slice of self that remains after dropping leading and trailing whitespace.
  public func strippingWhitespace() -> SubSequence
    where Element == Character
  {
    return self.drop { c in c.isWhitespace }
      .dropLast { c in c.isWhitespace }
  }

  /// Returns the lines from markdown fenced code blocks in `self` (having the
  /// given language if `language` is non-`nil`), paired with their line numbers.
  public func markdownCodeBlocks(language: String? = nil)
    -> [Zip2Collection<Range<Int>, [Self.SubSequence]>.SubSequence]
  {
    let allLines = self.split(omittingEmptySubsequences: false) { c in c.isNewline }.enumerated()
    let fence = "```" + (language ?? "")
    return allLines.subSequencesBetween(
      elementsSatisfying: { l in l.1.strippingWhitespace() == fence },
      and: { l in l.1.strippingWhitespace() == fence.prefix(3) }
    )
  }
}

