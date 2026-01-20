import Foundation

enum BlockNode: Hashable {
  case blockquote(children: [BlockNode])
  case bulletedList(isTight: Bool, items: [RawListItem])
  case numberedList(isTight: Bool, start: Int, items: [RawListItem])
  case taskList(isTight: Bool, items: [RawTaskListItem])
  case codeBlock(fenceInfo: String?, content: String)
  case htmlBlock(content: String)
  case paragraph(content: [InlineNode])
  case heading(level: Int, content: [InlineNode])
  case table(columnAlignments: [RawTableColumnAlignment], rows: [RawTableRow])
  case thematicBreak
  case multiBlock(children: [BlockNode])
}

extension BlockNode {
  var children: [BlockNode] {
    switch self {
    case .blockquote(let children):
      return children
    case .bulletedList(_, let items):
      return items.map(\.children).flatMap { $0 }
    case .numberedList(_, _, let items):
      return items.map(\.children).flatMap { $0 }
    case .taskList(_, let items):
      return items.map(\.children).flatMap { $0 }
    case .multiBlock(let children):
      return children
    default:
      return []
    }
  }

  var isParagraph: Bool {
    guard case .paragraph = self else { return false }
    return true
  }

  enum BlockType: Hashable {
      case paragraph
      case heading(Int)
      case blockquote
      case codeBlock
      case image
      case list
      case bulletedList
      case numberedList
      case taskList
      case listItem
      case table
      case tableCell
      case thematicBreak
  }

  var blockType: BlockType? {
      switch self {
      case .paragraph: return .paragraph
      case .heading(let level, _): return .heading(level)
      case .blockquote: return .blockquote
      case .codeBlock: return .codeBlock
      case .htmlBlock: return .paragraph // Treated as paragraph often
      case .table: return .table
      case .thematicBreak: return .thematicBreak
      case .bulletedList: return .bulletedList
      case .numberedList: return .numberedList
      case .taskList: return .taskList
      default: return nil
      }
  }
}

struct RawListItem: Hashable {
  let children: [BlockNode]
}

struct RawTaskListItem: Hashable {
  let isCompleted: Bool
  let children: [BlockNode]
}

enum RawTableColumnAlignment: Character {
  case none = "\0"
  case left = "l"
  case center = "c"
  case right = "r"
}

struct RawTableRow: Hashable {
  let cells: [RawTableCell]
}

struct RawTableCell: Hashable {
  let content: [InlineNode]
}
