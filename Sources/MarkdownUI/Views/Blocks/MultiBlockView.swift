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
      TextView(self.attributedText)
        .fixedSize(horizontal: false, vertical: true)
    #elseif os(macOS)
      // On macOS, we can use Text with AttributedString
      Text(AttributedString(self.attributedText))
        .fixedSize(horizontal: false, vertical: true)
    #else
      EmptyView()
    #endif
  }

  private var attributedText: NSAttributedString {
    let result = NSMutableAttributedString()

    for (index, block) in blocks.enumerated() {
      guard let type = block.blockType,
            let attributes = styles[type]
      else { continue }

      // 1. Render content to NSAttributedString
      let content: [InlineNode]
      switch block {
      case .paragraph(let c): content = c
      case .heading(_, let c): content = c
      default: content = []
      }

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
        attributes: attributes.textAttributes,
        colorScheme: self.colorScheme
      )

      let nsAttrStr = NSMutableAttributedString(attrStr.resolvingUIFonts())

      // 2. Calculate Spacing
      // We need to look ahead or look behind.
      // Strategy: Apply spacing to the END of this paragraph.
      // Spacing = max(this.bottom, next.top).
      
      let thisBottom = attributes.margins.bottom ?? 0
      var spacing: CGFloat = thisBottom

      if index < blocks.count - 1 {
        let nextBlock = blocks[index + 1]
        if let nextType = nextBlock.blockType,
           let nextAttributes = styles[nextType] {
          let nextTop = nextAttributes.margins.top ?? 0
          // MarkdownUI logic: max(top, prev_bottom)
          spacing = max(thisBottom, nextTop)
        }
      }

      // 3. Apply Paragraph Style
      // We need to get existing paragraph style or create one
      let fullRange = NSRange(location: 0, length: nsAttrStr.length)
      
      // Enumerate attributes to preserve existing styles (like code blocks inside text?)
      // But we want to apply block-level paragraph style.
      
      // Create a mutable paragraph style
      let pStyle = NSMutableParagraphStyle()
      pStyle.paragraphSpacing = spacing
      
      // If the theme provided a font, we might need to adjust line height?
      // MarkdownUI uses relativeLineSpacing.
      // This is usually handled in renderAttributedString if attributes has it.
      
      // We merge pStyle with existing pStyle if any
      nsAttrStr.enumerateAttribute(.paragraphStyle, in: fullRange, options: []) { (value, range, _) in
          let existing = (value as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle ?? pStyle.mutableCopy() as! NSMutableParagraphStyle
          existing.paragraphSpacing = spacing
          nsAttrStr.addAttribute(.paragraphStyle, value: existing, range: range)
      }
      
      // If no paragraph style was present, add it
      if nsAttrStr.length > 0 {
          // Check first char? Just add to whole string if missing?
          // The enumeration above handles ranges where it exists.
          // We should add it to the whole string, merging.
          // But enumeration is better.
          // Wait, if there is NO paragraph style, the loop runs once with nil value? 
          // No, enumerateAttribute runs for runs.
          // Better:
          nsAttrStr.addAttributes([.paragraphStyle: pStyle], range: fullRange)
      }
      
      // 4. Append
      result.append(nsAttrStr)
      
      // 5. Append Newline if not last
      if index < blocks.count - 1 {
          result.append(NSAttributedString(string: "\n"))
      }
    }
    
    return result
  }
}
