import Foundation

extension Sequence where Element == BlockNode {
  func coalesce() -> [BlockNode] {
    self.map { $0.coalesce() }
  }
}

extension BlockNode {
  func coalesce() -> BlockNode {
    switch self {
    case .paragraph(let content):
      return .paragraph(content: content.coalesceBlockMath())
    case .blockquote(let children):
      return .blockquote(children: children.coalesce())
    case .bulletedList(let isTight, let items):
      return .bulletedList(
        isTight: isTight,
        items: items.map { RawListItem(children: $0.children.coalesce()) }
      )
    case .numberedList(let isTight, let start, let items):
      return .numberedList(
        isTight: isTight,
        start: start,
        items: items.map { RawListItem(children: $0.children.coalesce()) }
      )
    case .taskList(let isTight, let items):
      return .taskList(
        isTight: isTight,
        items: items.map {
          RawTaskListItem(isCompleted: $0.isCompleted, children: $0.children.coalesce())
        }
      )
    case .heading(let level, let content):
      return .heading(level: level, content: content.coalesceBlockMath())
    case .table(let columnAlignments, let rows):
      return .table(
        columnAlignments: columnAlignments,
        rows: rows.map { row in
          RawTableRow(
            cells: row.cells.map { cell in
              RawTableCell(content: cell.content.coalesceBlockMath())
            }
          )
        }
      )
    default:
      return self
    }
  }
}

extension Array where Element == InlineNode {
  func coalesceBlockMath() -> [InlineNode] {
    var result: [InlineNode] = []
    var index = 0
    
    while index < self.count {
      let node = self[index]
      
      // We only process .text nodes that contain an unclosed math delimiter
      guard case .text(let content) = node,
            let (openDelim, openStart) = findUnclosedDelimiter(in: content)
      else {
        result.append(node)
        index += 1
        continue
      }
      
      // Found an unclosed delimiter. Now look ahead for the closing delimiter.
      var accumulator: [InlineNode] = []
      var foundClosing = false
      var lookAheadIndex = index + 1
      var closingSplit: (prefix: String, suffix: String)? = nil
      
      while lookAheadIndex < self.count {
        let nextNode = self[lookAheadIndex]
        
        if case .text(let nextContent) = nextNode {
          if let range = nextContent.range(of: openDelim) {
            // Found the closing delimiter
            foundClosing = true
            let prefix = String(nextContent[..<range.lowerBound])
            let suffix = String(nextContent[range.upperBound...])
            closingSplit = (prefix, suffix)
            break
          } else {
            accumulator.append(nextNode)
          }
        } else if case .softBreak = nextNode {
          accumulator.append(nextNode)
        } else if case .lineBreak = nextNode {
          accumulator.append(nextNode)
        } else {
          // Encountered a node that breaks the math block (e.g., image, code)
          break
        }
        lookAheadIndex += 1
      }
      
      if foundClosing, let split = closingSplit {
        // Merge the nodes into a single text node containing the full math block
        let prefixText = String(content[..<openStart])
        let mathStart = String(content[openStart...])
        
        var middleText = ""
        for accNode in accumulator {
          switch accNode {
          case .text(let t): middleText += t
          case .softBreak, .lineBreak: middleText += "\n"
          default: break
          }
        }
        
        let mathEnd = split.prefix + openDelim
        let fullMathText = mathStart + middleText + mathEnd
        
        if !prefixText.isEmpty {
          result.append(.text(prefixText))
        }
        
        result.append(.text(fullMathText))
        
        if !split.suffix.isEmpty {
          result.append(.text(split.suffix))
        }
        
        // Skip processed nodes
        index = lookAheadIndex + 1
      } else {
        // No closing delimiter found, treat as normal text
        result.append(node)
        index += 1
      }
    }
    
    return result
  }
  
  /// Scans the string for an unclosed math delimiter ($ or $$).
  /// Returns the delimiter and its starting index if found.
  private func findUnclosedDelimiter(in text: String) -> (delimiter: String, index: String.Index)? {
    var openDelimiter: String?
    var openIndex: String.Index?
    
    var index = text.startIndex
    while index < text.endIndex {
      let char = text[index]
      
      // Handle escaped characters
      if char == "\\" {
        index = text.index(after: index)
        if index < text.endIndex {
          index = text.index(after: index)
        }
        continue
      }
      
      // Handle Math Delimiters
      if char == "$" {
        // Check if it is "$$"
        let nextIndex = text.index(after: index)
        let isDouble = nextIndex < text.endIndex && text[nextIndex] == "$"
        
        let currentDelim = isDouble ? "$$" : "$"
        let currentDelimLen = isDouble ? 2 : 1
        
        if openDelimiter == currentDelim {
          // Found matching closer
          openDelimiter = nil
          openIndex = nil
        } else if openDelimiter == nil {
          // Found new opener
          openDelimiter = currentDelim
          openIndex = index
        }
        // If openDelimiter exists but differs (e.g. open="$" found "$$"), 
        // we treat the found delimiter as content inside the current block.
        
        index = text.index(index, offsetBy: currentDelimLen)
        continue
      }
      
      index = text.index(after: index)
    }
    
    if let delim = openDelimiter, let idx = openIndex {
      return (delim, idx)
    }
    return nil
  }
}
