import Foundation

extension BlockNode {
  var isMergeable: Bool {
    switch self {
    case .paragraph, .heading:
      return true
    case .bulletedList(_, let items):
        return items.allSatisfy { $0.children.allSatisfy(\.isMergeable) }
    case .numberedList(_, _, let items):
        return items.allSatisfy { $0.children.allSatisfy(\.isMergeable) }
    case .taskList(_, let items):
        return items.allSatisfy { $0.children.allSatisfy(\.isMergeable) }
    default:
      return false
    }
  }
}

extension Array where Element == BlockNode {
  func coalesced() -> [BlockNode] {
    var result: [BlockNode] = []
    var buffer: [BlockNode] = []

    for block in self {
      if block.isMergeable {
        buffer.append(block)
      } else {
        if !buffer.isEmpty {
          result.append(.multiBlock(children: buffer))
          buffer = []
        }
        result.append(block)
      }
    }
    
    if !buffer.isEmpty {
      result.append(.multiBlock(children: buffer))
    }
    
    return result
  }
}
