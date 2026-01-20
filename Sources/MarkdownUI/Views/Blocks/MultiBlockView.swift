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

  private func appendBlock(_ block: BlockNode, to result: NSMutableAttributedString, indentLevel: Int, isLast: Bool, nextBlock: BlockNode?, overrideSpacing: CGFloat? = nil) {
    // Determine styles
    let type = block.blockType ?? .paragraph // fallback
    let attributes = styles[type] ?? styles[.paragraph] // fallback

    // Spacing Calculation
    let thisBottom = attributes?.margins.bottom ?? 0
    var spacing: CGFloat = thisBottom

    if let override = overrideSpacing {
        spacing = override
    } else if let nextBlock = nextBlock,
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
        
    case .bulletedList(let isTight, let items):
        self.appendListItems(items, style: .bullet, isTight: isTight, to: result, indentLevel: indentLevel, spacing: spacing, attributes: attributes?.textAttributes)
        
    case .numberedList(let isTight, let start, let items):
        self.appendListItems(items, style: .number(start: start), isTight: isTight, to: result, indentLevel: indentLevel, spacing: spacing, attributes: attributes?.textAttributes)
        
    case .taskList(let isTight, let items):
        self.appendListItems(items, style: .task, isTight: isTight, to: result, indentLevel: indentLevel, spacing: spacing, attributes: attributes?.textAttributes)

    default:
        break // Should not happen if coalescing logic is correct
    }
    
    // Add newline if not last in this sequence
    if !isLast {
       // CRITICAL FIX: The newline must carry the paragraph style (spacing/indent) of the preceding block
       // to ensure the spacing is actually rendered by UITextView.
       // We reuse the attributes calculated for the block content if possible, or at least the spacing.
       
       let pStyle = NSMutableParagraphStyle()
       pStyle.paragraphSpacing = spacing
       // We might need to match indentation of the *next* block? 
       // Or the current? Paragraph spacing applies to the gap *after* the newline.
       // So it belongs to the current block.
       
       // We should try to capture the attributes used in the switch cases to apply here.
       // But `appendContent` creates its own pStyle internally.
       
       // Simplified approach: Create a newline with the correct spacing.
       let newline = NSMutableAttributedString(string: "\n")
       newline.addAttribute(NSAttributedString.Key.paragraphStyle, value: pStyle, range: NSRange(location: 0, length: 1))
       result.append(newline)
    }
  }

  enum ListStyle {
      case bullet
      case number(start: Int)
      case task
  }
  
  private func appendListItems<T>(_ items: [T], style: ListStyle, isTight: Bool, to result: NSMutableAttributedString, indentLevel: Int, spacing: CGFloat, attributes: AttributeContainer?) {
      // Use listItem attributes for content to ensure specific list styling is respected
      let listItemType = BlockNode.BlockType.listItem
      let listItemAttributes = self.styles[listItemType]
      
      // Basic Theme defaults: 
      // listItem top margin = 0.25em (~4.25pt at 17pt)
      // paragraph bottom margin = 1em (~17pt)
      let defaultFontSize = FontProperties.defaultSize
      let defaultListItemTop = defaultFontSize * 0.5
      let defaultParagraphBottom = defaultFontSize * 1.0
      
      let listItemTopMargin = listItemAttributes?.margins.top ?? defaultListItemTop
      
      // Calculate Indentation based on Font Size
      // Use the font size from the list item itself, or fallback to paragraph/default
      let contentFontProperties = listItemAttributes?.textAttributes.fontProperties ?? self.styles[.paragraph]?.textAttributes.fontProperties
      let fontSize = contentFontProperties?.size ?? defaultFontSize
      let indentUnit = fontSize * 2.0 
      
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
          
          // Calculate spacing for this item
          let itemSpacing: CGFloat
          if index == items.count - 1 {
              itemSpacing = spacing // Outer spacing
          } else {
              if isTight {
                   itemSpacing = listItemTopMargin
              } else {
                   // For loose lists, we want to ensure paragraph spacing is respected.
                   let pBottom = self.styles[.paragraph]?.margins.bottom ?? defaultParagraphBottom
                   itemSpacing = max(pBottom, listItemTopMargin)
              }
          }
          
          // Marker
          let marker: String
          switch style {
          case .bullet:
              let level = indentLevel + 1
              if level == 1 { marker = "•\t" }
              else if level == 2 { marker = "○\t" }
              else { marker = "■\t" }
          case .number(let start):
              marker = "\(start + index).\t"
          case .task:
              marker = isCompleted ? "☑\t" : "☐\t"
          }
          
          // Indentation logic
          let baseIndent: CGFloat = CGFloat(indentLevel) * indentUnit
          let itemIndent: CGFloat = indentUnit
          
          let pStyle = NSMutableParagraphStyle()
          pStyle.firstLineHeadIndent = baseIndent
          pStyle.headIndent = baseIndent + itemIndent
          pStyle.paragraphSpacing = 0 
          
          // Use itemSpacing for the marker line itself IF it has no children (unlikely) 
          // or if the first child is merged into it.
          // Actually, we merge the first child paragraph.
          // The paragraphSpacing of the merged paragraph will be set by appendContent.
          
          pStyle.tabStops = [NSTextTab(textAlignment: .left, location: baseIndent + itemIndent, options: [:])]
          
          let markerAttrStr = NSMutableAttributedString(string: marker)
          markerAttrStr.addAttribute(NSAttributedString.Key.paragraphStyle, value: pStyle, range: NSRange(location: 0, length: markerAttrStr.length))
          // Use standard label color for marker to avoid it disappearing if list item text has peculiar color, 
          // OR match list item text color? Usually matching text is better.
          // But user complained "did not achieve effect". 
          // Let's use the listItemAttributes for marker too.
          if let color = listItemAttributes?.textAttributes.foregroundColor {
               markerAttrStr.addAttribute(NSAttributedString.Key.foregroundColor, value: UIColor(color), range: NSRange(location: 0, length: markerAttrStr.length))
          } else {
               markerAttrStr.addAttribute(NSAttributedString.Key.foregroundColor, value: UIColor.label, range: NSRange(location: 0, length: markerAttrStr.length))
          }
           
           // Apply font
           if let fontProp = contentFontProperties {
                let uiFont = fontProp.resolveUIFont()
                markerAttrStr.addAttribute(.font, value: uiFont, range: NSRange(location: 0, length: markerAttrStr.length))
           }
          
          result.append(markerAttrStr)
          
          for (childIndex, child) in children.enumerated() {
              if childIndex == 0 {
                  if case .paragraph(let c) = child {
                       // CRITICAL FIX: Use listItemAttributes for content
                       self.appendContent(c, to: result, spacing: (childIndex == children.count - 1) ? itemSpacing : 0, indentLevel: indentLevel, overrideParagraphStyle: pStyle, attributes: listItemAttributes?.textAttributes, indentUnit: indentUnit)
                  } else {
                      let newline = NSMutableAttributedString(string: "\n")
                      newline.addAttribute(NSAttributedString.Key.paragraphStyle, value: pStyle, range: NSRange(location: 0, length: 1))
                      result.append(newline)
                      self.appendBlock(child, to: result, indentLevel: indentLevel + 1, isLast: childIndex == children.count - 1, nextBlock: nil, overrideSpacing: (childIndex == children.count - 1) ? itemSpacing : nil)
                  }
              } else {
                  let newline = NSMutableAttributedString(string: "\n")
                  // This intermediate newline should probably have 0 spacing if we are inside an item?
                  // Or should it have itemSpacing if it separates blocks?
                  // Usually 0.
                  let interBlockStyle = pStyle.mutableCopy() as! NSMutableParagraphStyle
                  interBlockStyle.paragraphSpacing = 0
                  newline.addAttribute(NSAttributedString.Key.paragraphStyle, value: interBlockStyle, range: NSRange(location: 0, length: 1))
                  result.append(newline)
                  
                   self.appendBlock(child, to: result, indentLevel: indentLevel + 1, isLast: childIndex == children.count - 1, nextBlock: nil, overrideSpacing: (childIndex == children.count - 1) ? itemSpacing : nil)
              }
          }
          
          if index < items.count - 1 {
              // Newline between list items
              // It must carry the spacing of the CURRENT item (itemSpacing) to separate it from the next.
              let newline = NSMutableAttributedString(string: "\n")
              let spacingStyle = NSMutableParagraphStyle()
              spacingStyle.paragraphSpacing = itemSpacing
              // Indent? Does not matter for empty newline, but good for consistency.
              spacingStyle.firstLineHeadIndent = baseIndent
              spacingStyle.headIndent = baseIndent
              
              newline.addAttribute(NSAttributedString.Key.paragraphStyle, value: spacingStyle, range: NSRange(location: 0, length: 1))
              result.append(newline)
          }
      }
  }

  private func appendContent(_ content: [InlineNode], to result: NSMutableAttributedString, spacing: CGFloat, indentLevel: Int, overrideParagraphStyle: NSMutableParagraphStyle? = nil, attributes: AttributeContainer?, indentUnit: CGFloat = 20.0) {
      
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
          let indent = CGFloat(indentLevel) * indentUnit
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
