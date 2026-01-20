import SwiftUI

struct CodeBlockView: View {
  @Environment(\.theme.codeBlock) private var codeBlock
  @Environment(\.codeSyntaxHighlighter) private var codeSyntaxHighlighter
  @Environment(\.colorScheme) private var colorScheme

  private let fenceInfo: String?
  private let content: String

  init(fenceInfo: String?, content: String) {
    self.fenceInfo = fenceInfo
    self.content = content.hasSuffix("\n") ? String(content.dropLast()) : content
  }

  var body: some View {
    self.codeBlock.makeBody(
      configuration: .init(
        language: self.fenceInfo,
        content: self.content,
        label: .init(self.label)
      )
    )
  }

  @ViewBuilder
  private var label: some View {
    if self.fenceInfo == "math" {
      TextStyleAttributesReader { attributes in
        let fontSize = attributes.fontProperties?.size ?? FontProperties.defaultSize
        let weight = attributes.fontProperties?.weight ?? FontProperties.defaultWeight
        let color = attributes.foregroundColor
        
        if let image = MathImageGenerator.image(
             for: self.content,
             fontSize: fontSize,
             weight: weight,
             color: color,
             colorScheme: self.colorScheme
           ) {
             image
        } else {
             Text(self.content)
        }
      }
    } else {
      self.codeSyntaxHighlighter.highlightCode(self.content, language: self.fenceInfo)
        .textStyleFont()
        .textStyleForegroundColor()
    }
  }
}
