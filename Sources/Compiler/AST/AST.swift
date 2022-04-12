/// An abstract syntax tree.
public struct AST {

  /// The nodes in `self`.
  // FIXME: Should be an array with tombstones.
  private var nodes: [Any] = []

  /// The indices of the modules.
  public private(set) var modules: [NodeID<ModuleDecl>] = []

  /// The source range of each node.
  public var ranges = NodeMap<SourceRange>()

  /// Creates an empty AST.
  public init() {}

  /// The ID of the module containing Val's standard library, if any.
  public var std: NodeID<ModuleDecl>?

  /// Returns the scope hierarchy.
  func scopeHierarchy() -> ScopeHierarchy {
    var builder = ScopeHierarchyBuilder()
    return builder.build(hierarchyOf: self)
  }

  /// Inserts `n` into `self`.
  public mutating func insert<T: Node>(_ n: T) -> NodeID<T> {
    let i = NodeID<T>(rawValue: nodes.count)
    nodes.append(n)
    if n is ModuleDecl { modules.append(i as! NodeID<ModuleDecl>) }
    return i
  }

  /// Accesses the node at `position` for reading or writing.
  public subscript<T: Node>(position: NodeID<T>) -> T {
    _read { yield nodes[position.rawValue] as! T }
    _modify {
      var n = nodes[position.rawValue] as! T
      defer { nodes[position.rawValue] = n }
      yield &n
    }
  }

  /// Accesses the node at `position` for reading.
  public subscript<T: Node>(position: NodeID<T>?) -> T? {
    _read { yield position.map({ nodes[$0.rawValue] as! T }) }
  }

  /// Accesses the node at `position` for reading.
  public subscript<T: NodeIDProtocol>(position: T) -> Node {
    _read { yield nodes[position.rawValue] as! Node }
  }

  /// Accesses the node at `position` for reading.
  public subscript<T: NodeIDProtocol>(position: T?) -> Node? {
    _read { yield position.map({ nodes[$0.rawValue] as! Node }) }
  }

  /// Accesses the node at `position` for reading.
  subscript(raw position: NodeID.RawValue) -> Any {
    _read { yield nodes[position] }
  }

}