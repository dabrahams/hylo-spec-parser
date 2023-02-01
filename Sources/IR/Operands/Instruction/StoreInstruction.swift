import Core

/// Stores `object` at the specified location.
public struct StoreInstruction: Instruction {

  /// The object to store.
  public let object: Operand

  /// The location at which the object is stored.
  public let target: Operand

  public let site: SourceRange

  init(_ object: Operand, to target: Operand, site: SourceRange) {
    self.object = object
    self.target = target
    self.site = site
  }

  public var types: [LoweredType] { [] }

  public var operands: [Operand] { [target] }

  public var isTerminator: Bool { false }

  public func isWellFormed(in module: Module) -> Bool {
    true
  }

}
