import SwiftUI

struct MultiBlockView: View {
  let blocks: [BlockNode]
  
  @Environment(\.blockStyles) private var styles
  @Environment(\.baseURL) private var baseURL
  @Environment(\.imageBaseURL) private var imageBaseURL
  @Environment(\.theme) private var theme
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.softBreakMode) private var softBreakMode

  var body: some View {
    #if os(iOS)
      TextView(attributedText: self.attributedText)
        .fixedSize(horizontal: false, vertical: true)
    #elseif os(macOS)
      Text(AttributedString(self.attributedText))
        .fixedSize(horizontal: false, vertical: true)
    #else
      EmptyView()
    #endif
  }

  private var attributedText: NSAttributedString {
    let result = NSMutableAttributedString()
    self.appendBlocks(blocks, to: result, indentLevel: 0)
    return result
  }

  private func appendBlocks(_ blocks: [BlockNode], to result: NSMutableAttributedString, indentLevel: Int) {
    for (index, block) in blocks.enumerated() {
        self.appendBlock(block, to: result, indentLevel: indentLevel, isLast: index == blocks.count - 1, nextBlock: index < blocks.count - 1 ? blocks[index+1] : nil)
    }
  }

  private func appendBlock(_ block: BlockNode, to result: NSMutableAttributedString, indentLevel: Int, isLast: Bool, nextBlock: BlockNode?) {
    // Determine styles
    let type = block.blockType ?? .paragraph // fallback
    let attributes = styles[type] ?? styles[.paragraph] // fallback

    // Spacing Calculation
    let thisBottom = attributes?.margins.bottom ?? 0
    var spacing: CGFloat = thisBottom

    if let nextBlock = nextBlock,
       let nextType = nextBlock.blockType,
       let nextAttributes = styles[nextType] {
       let nextTop = nextAttributes.margins.top ?? 0
       spacing = max(thisBottom, nextTop)
    }

    // Adjust font size if theme attributes are missing (e.g. List usually doesn't set font, Paragraph does)
    // If attributes is nil or empty text attributes, try to use Paragraph attributes as base for text content?
    // Actually, usually we want to inherit.
    
    // For lists, we often don't get text attributes from the List style itself.
    // We should fallback to paragraph attributes for the content of the list if needed.
    // But `appendContent` will use passed `attributes`.
    
    switch block {
    case .paragraph(let content), .heading(_, let content):
        self.appendContent(content, to: result, spacing: spacing, indentLevel: indentLevel, attributes: attributes?.textAttributes)
        
    case .blockquote(let children):
        // Indent level increases
        self.appendBlocks(children, to: result, indentLevel: indentLevel + 1)
        
    case .bulletedList(_, let items):
        self.appendListItems(items, style: .bullet, to: result, indentLevel: indentLevel, spacing: spacing, attributes: attributes?.textAttributes)
        
    case .numberedList(_, let start, let items):
        self.appendListItems(items, style: .number(start: start), to: result, indentLevel: indentLevel, spacing: spacing, attributes: attributes?.textAttributes)
        
    case .taskList(_, let items):
        self.appendListItems(items, style: .task, to: result, indentLevel: indentLevel, spacing: spacing, attributes: attributes?.textAttributes)

    default:
        break // Should not happen if coalescing logic is correct
    }
    
    // Add newline if not last in this sequence
    if !isLast {
       result.append(NSAttributedString(string: "\n"))
    }
  }

  enum ListStyle {
      case bullet
      case number(start: Int)
      case task
  }
  
  private func appendListItems<T>(_ items: [T], style: ListStyle, to result: NSMutableAttributedString, indentLevel: Int, spacing: CGFloat, attributes: AttributeContainer?) {
      for (index, item) in items.enumerated() {
          let children: [BlockNode]
          let isCompleted: Bool
          
          if let item = item as? RawListItem {
              children = item.children
              isCompleted = false
          } else if let item = item as? RawTaskListItem {
              children = item.children
              isCompleted = item.isCompleted
          } else {
              continue
          }
          
          // Marker
          let marker: String
          switch style {
          case .bullet: marker = "•\t"
          case .number(let start): marker = "\(start + index).\t"
          case .task: marker = isCompleted ? "[x]\t" : "[ ]\t"
          }
          
          // Indentation for list item
          // Standard indentation: 20pt * level?
          // We need hanging indent.
          let baseIndent: CGFloat = CGFloat(indentLevel) * 20.0
          let itemIndent: CGFloat = 20.0
          
          let pStyle = NSMutableParagraphStyle()
          pStyle.firstLineHeadIndent = baseIndent
          pStyle.headIndent = baseIndent + itemIndent
          pStyle.paragraphSpacing = 0 // Tight list? 
          // If the list is NOT tight, we might want spacing. 
          // For now assume tight inside list items, but spacing after list?
          // Actually MarkdownUI passes `isTight` param. 
          
          // We'll apply the spacing to the last block of the item.
          
          // Construct the marker string
          // We apply standard font to marker?
          let markerAttrStr = NSMutableAttributedString(string: marker)
          markerAttrStr.addAttribute(NSAttributedString.Key.paragraphStyle, value: pStyle, range: NSRange(location: 0, length: markerAttrStr.length))
          // Add standard color/font
           markerAttrStr.addAttribute(NSAttributedString.Key.foregroundColor, value: UIColor.label, range: NSRange(location: 0, length: markerAttrStr.length))
           
           // Apply attributes to marker if present (e.g. font size)
           if let attributes = attributes {
                let temp = AttributedString(marker, attributes: attributes)
                let nsTemp = temp.resolvingUIFonts() // Convert to NSAttributedString with font
                // Merge into markerAttrStr
                // Actually easier to just use the resolvingUIFonts logic helper if we can.
                // But marker is plain string.
                // Let's manually apply font if found in attributes
                if let fontProp = attributes.fontProperties {
                     let uiFont = fontProp.resolveUIFont()
                     markerAttrStr.addAttribute(.font, value: uiFont, range: NSRange(location: 0, length: markerAttrStr.length))
                }
           }
          
          result.append(markerAttrStr)
          
          // Render Children
          // The first child is usually on the same line as marker.
          // If first child is paragraph, we inline it.
          // If multiple blocks, subsequent blocks need full indentation (headIndent).
          
          for (childIndex, child) in children.enumerated() {
              if childIndex == 0 {
                  // Merge with marker line
                  // But `appendBlock` adds content.
                  // We need to strip the newline from marker? No marker didn't have newline.
                  // We need `appendBlock` to use the SAME paragraph style but maybe modifying indent?
                  // Actually, `appendContent` creates its own paragraph style.
                  // We should pass the pStyle to `appendContent`.
                  
                  if case .paragraph(let c) = child {
                       // Pass styles[.paragraph] attributes effectively?
                       // Actually, we should use the paragraph style for the text content, NOT the list style.
                       // So we need to fetch paragraph attributes.
                       let pType = BlockNode.BlockType.paragraph
                       let pAttributes = self.styles[pType]
                       
                       self.appendContent(c, to: result, spacing: (childIndex == children.count - 1) ? spacing : 0, indentLevel: indentLevel, overrideParagraphStyle: pStyle, attributes: pAttributes?.textAttributes)
                  } else {
                      // If it's not a paragraph (e.g. nested list immediately?), new line?
                      // Usually list item starts with paragraph.
                      result.append(NSAttributedString(string: "\n"))
                      self.appendBlock(child, to: result, indentLevel: indentLevel + 1, isLast: childIndex == children.count - 1, nextBlock: nil)
                  }
              } else {
                  // Subsequent blocks
                  result.append(NSAttributedString(string: "\n"))
                  // They should be indented to align with text (base + itemIndent)
                   self.appendBlock(child, to: result, indentLevel: indentLevel + 1, isLast: childIndex == children.count - 1, nextBlock: nil)
              }
          }
          
          if index < items.count - 1 {
              result.append(NSAttributedString(string: "\n"))
          }
      }
  }

  private func appendContent(_ content: [InlineNode], to result: NSMutableAttributedString, spacing: CGFloat, indentLevel: Int, overrideParagraphStyle: NSMutableParagraphStyle? = nil, attributes: AttributeContainer?) {
      
      let textStyles = InlineTextStyles(
        code: self.theme.code,
        emphasis: self.theme.emphasis,
        strong: self.theme.strong,
        strikethrough: self.theme.strikethrough,
        link: self.theme.link
      )
      
      let attrStr = content.renderAttributedString(
        baseURL: self.baseURL,
        textStyles: textStyles,
        softBreakMode: self.softBreakMode,
        attributes: attributes ?? AttributeContainer(), // Use passed attributes or empty
        colorScheme: self.colorScheme
      )
      
      let nsAttrStr = NSMutableAttributedString(attributedString: attrStr.resolvingUIFonts())
      
      let fullRange = NSRange(location: 0, length: nsAttrStr.length)
      
      // Paragraph Style
      let pStyle: NSMutableParagraphStyle
      if let override = overrideParagraphStyle {
          pStyle = override
      } else {
          pStyle = NSMutableParagraphStyle()
          let indent = CGFloat(indentLevel) * 20.0
          pStyle.firstLineHeadIndent = indent
          pStyle.headIndent = indent
      }
      pStyle.paragraphSpacing = spacing
      
      // Apply pStyle
      nsAttrStr.enumerateAttribute(NSAttributedString.Key.paragraphStyle, in: fullRange, options: []) { (value, range, _) in
          let existing = (value as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle ?? pStyle.mutableCopy() as! NSMutableParagraphStyle
          // Merge properties
          existing.firstLineHeadIndent = pStyle.firstLineHeadIndent
          existing.headIndent = pStyle.headIndent
          existing.paragraphSpacing = pStyle.paragraphSpacing
          // Keep existing tab stops?
          if !pStyle.tabStops.isEmpty {
               existing.tabStops = pStyle.tabStops
          }
           nsAttrStr.addAttribute(NSAttributedString.Key.paragraphStyle, value: existing, range: range)
      }
      
      if nsAttrStr.length > 0 {
           // Ensure base pStyle is applied if missing
           // But enumeration covers it.
           // Just in case whole string has no pStyle:
           nsAttrStr.addAttributes([NSAttributedString.Key.paragraphStyle: pStyle], range: fullRange)
      }
      
      result.append(nsAttrStr)
  }
}
