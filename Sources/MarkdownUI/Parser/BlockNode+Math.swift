import Foundation

extension Sequence where Element == BlockNode {
  func parseBlockMath() -> [BlockNode] {
    self.flatMap { $0.parseBlockMath() }
  }
}

extension BlockNode {
  func parseBlockMath() -> [BlockNode] {
    switch self {
    case .paragraph(let content):
      return content.parseBlockMath()
    case .blockquote(let children):
      return [.blockquote(children: children.parseBlockMath())]
    case .bulletedList(let isTight, let items):
      return [.bulletedList(isTight: isTight, items: items.map { $0.parseBlockMath() })]
    case .numberedList(let isTight, let start, let items):
      return [.numberedList(isTight: isTight, start: start, items: items.map { $0.parseBlockMath() })]
    case .taskList(let isTight, let items):
      return [.taskList(isTight: isTight, items: items.map { $0.parseBlockMath() })]
    case .multiBlock(let children):
      return children.parseBlockMath()
    case .heading, .codeBlock, .htmlBlock, .table, .thematicBreak:
      return [self]
    }
  }
}

extension RawListItem {
  func parseBlockMath() -> RawListItem {
    RawListItem(children: self.children.parseBlockMath())
  }
}

extension RawTaskListItem {
  func parseBlockMath() -> RawTaskListItem {
    RawTaskListItem(isCompleted: self.isCompleted, children: self.children.parseBlockMath())
  }
}

extension Array where Element == InlineNode {
  fileprivate func parseBlockMath() -> [BlockNode] {
    var result: [BlockNode] = []
    var currentParagraphInlines: [InlineNode] = []
    
    for node in self {
      if case .text(let content) = node {
        // Regex to find $$ ... $$
        // We use the same pattern as in InlineNode+Math.swift but only for Block Math
        let pattern = "(?s)\\$\\$(.+?)\\$\\$"
        
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
          currentParagraphInlines.append(node)
          continue
        }
        
        let matches = regex.matches(in: content, range: NSRange(content.startIndex..., in: content))
        
        if matches.isEmpty {
          currentParagraphInlines.append(node)
          continue
        }
        
        var lastIndex = content.startIndex
        
        for match in matches {
            let matchRange = Range(match.range, in: content)!
            let mathContentRange = Range(match.range(at: 1), in: content)!
            
            // 1. Text before the math block
            if matchRange.lowerBound > lastIndex {
                let textBefore = String(content[lastIndex..<matchRange.lowerBound])
                // Only append if it's not just whitespace? 
                // Markdown spec says block math usually requires newlines, but here we are being lenient.
                if !textBefore.isEmpty {
                    currentParagraphInlines.append(.text(textBefore))
                }
            }
            
            // 2. Flush the current paragraph if it has content
            if !currentParagraphInlines.isEmpty {
                // Check if paragraph is only whitespace?
                // For now, we emit it. A paragraph with just space is valid but invisible.
                // Optimally we could trim it.
                result.append(.paragraph(content: currentParagraphInlines))
                currentParagraphInlines = []
            }
            
            // 3. Create the Math Block
            let mathContent = String(content[mathContentRange])
            // We use "math" as the language for the code block to trigger special rendering
            result.append(.codeBlock(fenceInfo: "math", content: mathContent))
            
            lastIndex = matchRange.upperBound
        }
        
        // 4. Remaining text after the last match
        if lastIndex < content.endIndex {
            let textAfter = String(content[lastIndex...])
            if !textAfter.isEmpty {
                currentParagraphInlines.append(.text(textAfter))
            }
        }
        
      } else {
        currentParagraphInlines.append(node)
      }
    }
    
    // Flush any remaining inline content as a final paragraph
    if !currentParagraphInlines.isEmpty {
      result.append(.paragraph(content: currentParagraphInlines))
    }
    
    return result
  }
}
