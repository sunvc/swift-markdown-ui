#if canImport(UIKit)
import SwiftUI

/// 一个支持选择复制的 Markdown 视图，通过 NSAttributedString 渲染到 UITextView 中。
public struct SelectableMarkdown: View {
    @Environment(\.theme) private var theme
    @Environment(\.baseURL) private var baseURL
    @Environment(\.softBreakMode) private var softBreakMode
    
    private let content: MarkdownContent
    private let highlightText: String?
    private let highlightColor: Color?
    
    public init(_ markdown: String, highlightText: String? = nil, highlightColor: Color? = .blue) {
        self.content = MarkdownContent(markdown)
        self.highlightText = highlightText
        self.highlightColor = highlightColor
    }
    
    public init(content: MarkdownContent, highlightText: String? = nil, highlightColor: Color? = .blue) {
        self.content = content
        self.highlightText = highlightText
        self.highlightColor = highlightColor
    }
    
    public var body: some View {
        TextStyleAttributesReader { attributes in
            SelectableMarkdownBody(
                blocks: content.blocks,
                theme: theme,
                baseURL: baseURL,
                softBreakMode: softBreakMode,
                baseAttributes: attributes,
                highlightText: highlightText,
                highlightColor: highlightColor
            )
        }
        .textStyle(theme.text)
    }
}

private struct SelectableMarkdownBody: View {
    let blocks: [BlockNode]
    let theme: Theme
    let baseURL: URL?
    let softBreakMode: SoftBreak.Mode
    let baseAttributes: AttributeContainer
    let highlightText: String?
    let highlightColor: Color?
    
    @ScaledMetric private var size: CGFloat
    
    init(
        blocks: [BlockNode],
        theme: Theme,
        baseURL: URL?,
        softBreakMode: SoftBreak.Mode,
        baseAttributes: AttributeContainer,
        highlightText: String? = nil,
        highlightColor: Color? = nil
    ) {
        self.blocks = blocks
        self.theme = theme
        self.baseURL = baseURL
        self.softBreakMode = softBreakMode
        self.baseAttributes = baseAttributes
        self.highlightText = highlightText
        self.highlightColor = highlightColor
        self._size = ScaledMetric(
            wrappedValue: baseAttributes.fontProperties?.size ?? FontProperties.defaultSize,
            relativeTo: .body
        )
    }
    
    var body: some View {
        var effectiveAttributes = baseAttributes
        if effectiveAttributes.fontProperties == nil {
            effectiveAttributes.fontProperties = FontProperties()
        }
        effectiveAttributes.fontProperties?.size = size
        
        let attributedString = blocks.renderNSAttributedString(
            theme: theme,
            baseURL: baseURL,
            softBreakMode: softBreakMode,
            baseAttributes: effectiveAttributes
        )
        
        // 应用高亮逻辑
        let finalAttributedString = applyHighlight(
            to: attributedString,
            text: highlightText,
            color: highlightColor
        )
        
        return CustomTapTextViewRepresentable(
            attributedString: finalAttributedString
        )
        .fixedSize(horizontal: false, vertical: true)
    }
    
    private func applyHighlight(to attributedString: NSAttributedString, text: String?, color: Color?) -> NSAttributedString {
        guard let text = text, !text.isEmpty, let color = color else {
            return attributedString
        }
        
        let mutable = NSMutableAttributedString(attributedString: attributedString)
        let string = mutable.string as NSString
        var searchRange = NSRange(location: 0, length: string.length)
        
        let uiColor = UIColor(color)
        
        while searchRange.location != NSNotFound {
            let foundRange = string.range(of: text, options: .caseInsensitive, range: searchRange)
            if foundRange.location != NSNotFound {
                // 1. 设置字体颜色
                mutable.addAttribute(.foregroundColor, value: uiColor, range: foundRange)
                
                // 2. 增加加粗效果
                mutable.enumerateAttribute(.font, in: foundRange, options: []) { (font, range, stop) in
                    if let font = font as? UIFont {
                        let boldFont: UIFont
                        if let descriptor = font.fontDescriptor.withSymbolicTraits(.traitBold) {
                            boldFont = UIFont(descriptor: descriptor, size: font.pointSize)
                        } else {
                            boldFont = UIFont.boldSystemFont(ofSize: font.pointSize)
                        }
                        mutable.addAttribute(.font, value: boldFont, range: range)
                    }
                }
                
                // 更新搜索范围
                let nextLocation = foundRange.location + foundRange.length
                searchRange = NSRange(location: nextLocation, length: string.length - nextLocation)
            } else {
                searchRange.location = NSNotFound
            }
        }
        
        return mutable
    }
}
#endif
