import Foundation

extension StringProtocol {

  /// Returns the slice of self that remains after dropping leading and trailing whitespace.
  public func strippingWhitespace() -> SubSequence
    where Element == Character
  {
    return self.drop { c in c.isWhitespace }
      .dropLast { c in c.isWhitespace }
  }

}
