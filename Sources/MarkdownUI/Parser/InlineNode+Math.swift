import Foundation

extension InlineNode {
  static func parseMath(_ node: InlineNode) -> [InlineNode] {
    switch node {
    case .code(let content):
      // Support math inside inline code blocks (e.g. `$x$` or `$$x$$`)
      if content.hasPrefix("$$") && content.hasSuffix("$$") && content.count >= 4 {
        let math = String(content.dropFirst(2).dropLast(2))
        return [.math(math)]
      }
      if content.hasPrefix("$") && content.hasSuffix("$") && content.count >= 2 {
        let math = String(content.dropFirst().dropLast())
        return [.math(math)]
      }
      return [node]

    case .text(let content):
      // Combine Block and Inline regex or process sequentially.
      
      // 1. Regex definitions
      // Block: $$ ... $$ (dot matches newlines)
      let blockPattern = "(?s)\\$\\$(.+?)\\$\\$"
      // Inline: $ ... $ (no newlines, negative lookahead for $)
      let inlinePattern = "(?s)\\$(?!\\$)((?:\\\\\\$|[^$])+)\\$"
      
      // We will use a combined pattern to iterate through the string once,
      // prioritizing Block math (which matches $$) over Inline math.
      // Pattern: Block | Inline
      let pattern = "\(blockPattern)|\(inlinePattern)"
      
      let regex = try! NSRegularExpression(pattern: pattern)
      let range = NSRange(content.startIndex..<content.endIndex, in: content)
      let matches = regex.matches(in: content, options: [], range: range)

      guard !matches.isEmpty else {
        return [node]
      }

      var result: [InlineNode] = []
      var lastEndIndex = content.startIndex

      for match in matches {
        let matchRange = match.range(at: 0)
        
        let blockContentRange = match.range(at: 1)
        let inlineContentRange = match.range(at: 2)
        
        let mathContent: String
        
        if blockContentRange.location != NSNotFound {
          guard let r = Range(blockContentRange, in: content) else { continue }
          mathContent = String(content[r])
        } else if inlineContentRange.location != NSNotFound {
          guard let r = Range(inlineContentRange, in: content) else { continue }
          mathContent = String(content[r])
        } else {
          continue
        }

        guard let matchStringRange = Range(matchRange, in: content) else { continue }

        // Add preceding text
        if lastEndIndex < matchStringRange.lowerBound {
          result.append(.text(String(content[lastEndIndex..<matchStringRange.lowerBound])))
        }

        // Add math node
        result.append(.math(mathContent))

        lastEndIndex = matchStringRange.upperBound
      }

      // Add remaining text
      if lastEndIndex < content.endIndex {
        result.append(.text(String(content[lastEndIndex...])))
      }

      return result

    default:
      return [node]
    }
  }
}
