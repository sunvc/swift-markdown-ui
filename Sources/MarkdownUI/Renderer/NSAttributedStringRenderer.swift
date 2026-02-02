#if canImport(UIKit)
import Foundation
import SwiftUI
import UIKit

extension Sequence where Element == InlineNode {
    func renderNSAttributedString(
        baseURL: URL?,
        textStyles: InlineTextStyles,
        softBreakMode: SoftBreak.Mode,
        attributes: AttributeContainer
    ) -> AttributedString {
        var renderer = RawAttributedStringInlineRenderer(
            baseURL: baseURL,
            textStyles: textStyles,
            softBreakMode: softBreakMode,
            attributes: attributes
        )
        for inline in self {
            renderer.render(inline)
        }
        return renderer.result.resolvingUIStyles()
    }
}

private struct RawAttributedStringInlineRenderer {
    var result = AttributedString()
    private let baseURL: URL?
    private let textStyles: InlineTextStyles
    private let softBreakMode: SoftBreak.Mode
    private var attributes: AttributeContainer
    private var shouldSkipNextWhitespace = false

    init(
        baseURL: URL?,
        textStyles: InlineTextStyles,
        softBreakMode: SoftBreak.Mode,
        attributes: AttributeContainer
    ) {
        self.baseURL = baseURL
        self.textStyles = textStyles
        self.softBreakMode = softBreakMode
        self.attributes = attributes
    }

    mutating func render(_ inline: InlineNode) {
        switch inline {
        case .text(let content):
            self.renderText(content)
        case .softBreak:
            self.renderSoftBreak()
        case .lineBreak:
            self.renderLineBreak()
        case .code(let content):
            self.renderCode(content)
        case .html(let content):
            self.renderHTML(content)
        case .emphasis(let children):
            self.renderEmphasis(children: children)
        case .strong(let children):
            self.renderStrong(children: children)
        case .strikethrough(let children):
            self.renderStrikethrough(children: children)
        case .link(let destination, let children):
            self.renderLink(destination: destination, children: children)
        case .image:
            break // 不支持图片
        }
    }

    private mutating func renderText(_ text: String) {
        var text = text
        if self.shouldSkipNextWhitespace {
            self.shouldSkipNextWhitespace = false
            text = text.replacingOccurrences(of: "^\\s+", with: "", options: .regularExpression)
        }
        self.result += .init(text, attributes: self.attributes)
    }

    private mutating func renderSoftBreak() {
        switch softBreakMode {
        case .space where self.shouldSkipNextWhitespace:
            self.shouldSkipNextWhitespace = false
        case .space:
            self.result += .init(" ", attributes: self.attributes)
        case .lineBreak:
            self.renderLineBreak()
        }
    }

    private mutating func renderLineBreak() {
        self.result += .init("\n", attributes: self.attributes)
    }

    private mutating func renderCode(_ code: String) {
        var codeAttributes = self.attributes
        self.textStyles.code._collectAttributes(in: &codeAttributes)
        self.result += .init(code, attributes: codeAttributes)
    }

    private mutating func renderHTML(_ html: String) {
        let tag = HTMLTag(html)
        switch tag?.name.lowercased() {
        case "br":
            self.renderLineBreak()
            self.shouldSkipNextWhitespace = true
        default:
            self.renderText(html)
        }
    }

    private mutating func renderEmphasis(children: [InlineNode]) {
        let savedAttributes = self.attributes
        self.textStyles.emphasis._collectAttributes(in: &self.attributes)
        for child in children { self.render(child) }
        self.attributes = savedAttributes
    }

    private mutating func renderStrong(children: [InlineNode]) {
        let savedAttributes = self.attributes
        self.textStyles.strong._collectAttributes(in: &self.attributes)
        for child in children { self.render(child) }
        self.attributes = savedAttributes
    }

    private mutating func renderStrikethrough(children: [InlineNode]) {
        let savedAttributes = self.attributes
        self.textStyles.strikethrough._collectAttributes(in: &self.attributes)
        for child in children { self.render(child) }
        self.attributes = savedAttributes
    }

    private mutating func renderLink(destination: String, children: [InlineNode]) {
        let savedAttributes = self.attributes
        self.textStyles.link._collectAttributes(in: &self.attributes)
        self.attributes.link = URL(string: destination, relativeTo: self.baseURL)
        for child in children { self.render(child) }
        self.attributes = savedAttributes
    }
}

extension AttributedString {
    func resolvingUIStyles() -> AttributedString {
        var output = self
        for run in output.runs {
            if let fontProperties = run.fontProperties {
                output[run.range].uiKit.font = fontProperties.uiFont()
                output[run.range].fontProperties = nil
            }
            if let color = run.foregroundColor {
                output[run.range].uiKit.foregroundColor = UIColor(color)
            }
            if let backgroundColor = run.backgroundColor {
                output[run.range].uiKit.backgroundColor = UIColor(backgroundColor)
            }
            if let strikethroughStyle = run.strikethroughStyle {
                output[run.range].uiKit.strikethroughStyle = NSUnderlineStyle(strikethroughStyle)
            }
            if let underlineStyle = run.underlineStyle {
                output[run.range].uiKit.underlineStyle = NSUnderlineStyle(underlineStyle)
            }
            if let kern = run.kern {
                output[run.range].uiKit.kern = kern
            }
            if let tracking = run.tracking {
                // UIKit doesn't have tracking, but we can approximate with kern
                output[run.range].uiKit.kern = tracking
            }
        }
        return output
    }
}

extension NSUnderlineStyle {
    init(_ lineStyle: Text.LineStyle) {
        // 这是一个简化的映射
        self = .single
    }
}

extension FontProperties {
    func uiFont() -> UIFont {
        let size = round(self.size * self.scale)
        var font: UIFont
        
        switch self.family {
        case .system(let design):
            switch design {
            case .monospaced:
                font = UIFont.monospacedSystemFont(ofSize: size, weight: self.uiKitWeight)
            case .serif:
                font = UIFont(name: "Times New Roman", size: size) ?? .systemFont(ofSize: size, weight: self.uiKitWeight)
            case .rounded:
                if let descriptor = UIFont.systemFont(ofSize: size).fontDescriptor.withDesign(.rounded) {
                    font = UIFont(descriptor: descriptor, size: size)
                } else {
                    font = .systemFont(ofSize: size, weight: self.uiKitWeight)
                }
            default:
                font = .systemFont(ofSize: size, weight: self.uiKitWeight)
            }
        case .custom(let name):
            font = UIFont(name: name, size: size) ?? .systemFont(ofSize: size, weight: self.uiKitWeight)
        }
        
        if self.style == .italic {
            if let descriptor = font.fontDescriptor.withSymbolicTraits(.traitItalic) {
                font = UIFont(descriptor: descriptor, size: size)
            }
        }
        
        return font
    }
    
    private var uiKitWeight: UIFont.Weight {
        if self.weight == .ultraLight { return .ultraLight }
        if self.weight == .thin { return .thin }
        if self.weight == .light { return .light }
        if self.weight == .regular { return .regular }
        if self.weight == .medium { return .medium }
        if self.weight == .semibold { return .semibold }
        if self.weight == .bold { return .bold }
        if self.weight == .heavy { return .heavy }
        if self.weight == .black { return .black }
        return .regular
    }
}

extension Array where Element == BlockNode {
    func renderNSAttributedString(
        theme: Theme,
        baseURL: URL?,
        softBreakMode: SoftBreak.Mode,
        baseAttributes: AttributeContainer? = nil
    ) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let inlineTextStyles = InlineTextStyles(
            code: theme.code,
            emphasis: theme.emphasis,
            strong: theme.strong,
            strikethrough: theme.strikethrough,
            link: theme.link
        )
        
        var effectiveAttributes = baseAttributes ?? AttributeContainer()
        if baseAttributes == nil {
            theme.text._collectAttributes(in: &effectiveAttributes)
        }
        
        for (index, block) in self.enumerated() {
            let blockNS = block.renderToNS(
                theme: theme,
                baseURL: baseURL,
                textStyles: inlineTextStyles,
                softBreakMode: softBreakMode,
                attributes: effectiveAttributes
            )
            
            result.append(blockNS)
            
            if index < self.count - 1 {
                result.append(NSAttributedString(string: "\n\n"))
            }
        }
        
        return result
    }
}

extension BlockNode {
    fileprivate func renderToNS(
        theme: Theme,
        baseURL: URL?,
        textStyles: InlineTextStyles,
        softBreakMode: SoftBreak.Mode,
        attributes: AttributeContainer
    ) -> NSAttributedString {
        var blockAttributes = attributes
        
        switch self {
        case .paragraph(let content):
            let attrString = content.renderNSAttributedString(
                baseURL: baseURL,
                textStyles: textStyles,
                softBreakMode: softBreakMode,
                attributes: blockAttributes
            )
            return NSAttributedString(attrString)
            
        case .heading(let level, let content):
            // 简单的标题缩放逻辑
            let scale: CGFloat
            switch level {
            case 1: scale = 2.0
            case 2: scale = 1.5
            case 3: scale = 1.17
            case 4: scale = 1.0
            case 5: scale = 0.83
            case 6: scale = 0.67
            default: scale = 1.0
            }
            
            blockAttributes.fontProperties?.scale = scale
            FontWeight(.semibold)._collectAttributes(in: &blockAttributes)
            
            let attrString = content.renderNSAttributedString(
                baseURL: baseURL,
                textStyles: textStyles,
                softBreakMode: softBreakMode,
                attributes: blockAttributes
            )
            
            return NSAttributedString(attrString)
            
        case .bulletedList(_, let items):
            let result = NSMutableAttributedString()
            for (index, item) in items.enumerated() {
                let itemString = item.children.renderNSAttributedString(
                    theme: theme,
                    baseURL: baseURL,
                    softBreakMode: softBreakMode,
                    baseAttributes: blockAttributes
                )
                let bulletAttr = AttributedString("• ", attributes: blockAttributes).resolvingUIStyles()
                let bullet = NSAttributedString(bulletAttr)
                let combined = NSMutableAttributedString(attributedString: bullet)
                combined.append(itemString)
                result.append(combined)
                if index < items.count - 1 {
                    result.append(NSAttributedString(string: "\n"))
                }
            }
            return result
            
        case .numberedList(_, let start, let items):
            let result = NSMutableAttributedString()
            for (index, item) in items.enumerated() {
                let itemString = item.children.renderNSAttributedString(
                    theme: theme,
                    baseURL: baseURL,
                    softBreakMode: softBreakMode,
                    baseAttributes: blockAttributes
                )
                let numberAttr = AttributedString("\(start + index). ", attributes: blockAttributes).resolvingUIStyles()
                let number = NSAttributedString(numberAttr)
                let combined = NSMutableAttributedString(attributedString: number)
                combined.append(itemString)
                result.append(combined)
                if index < items.count - 1 {
                    result.append(NSAttributedString(string: "\n"))
                }
            }
            return result
            
        case .blockquote(let children):
            var quoteAttributes = blockAttributes
            FontStyle(.italic)._collectAttributes(in: &quoteAttributes)
            let content = children.renderNSAttributedString(
                theme: theme, 
                baseURL: baseURL, 
                softBreakMode: softBreakMode,
                baseAttributes: quoteAttributes
            )
            return content
            
        case .codeBlock(_, let content):
            var codeAttributes = blockAttributes
            FontFamilyVariant(.monospaced)._collectAttributes(in: &codeAttributes)
            // 默认给代码块一个小一点的字号
            codeAttributes.fontProperties?.scale *= 0.9
            let codeAttr = AttributedString(content, attributes: codeAttributes).resolvingUIStyles()
            return NSAttributedString(codeAttr)
            
        case .table(_, let rows):
            let result = NSMutableAttributedString()
            
            // 1. 预渲染所有单元格并计算每列的最大宽度
            var columnWidths: [CGFloat] = []
            var renderedRows: [[NSAttributedString]] = []
            
            for row in rows {
                var renderedRow: [NSAttributedString] = []
                for (cellIndex, cell) in row.cells.enumerated() {
                    let cellAttr = cell.content.renderNSAttributedString(
                        baseURL: baseURL,
                        textStyles: textStyles,
                        softBreakMode: softBreakMode,
                        attributes: blockAttributes
                    )
                    let cellString = NSAttributedString(cellAttr)
                    renderedRow.append(cellString)
                    
                    // 计算该单元格宽度（向上取整以避免微小偏差导致换行）
                    let cellWidth = ceil(cellString.size().width)
                    if cellIndex >= columnWidths.count {
                        columnWidths.append(cellWidth)
                    } else {
                        columnWidths[cellIndex] = max(columnWidths[cellIndex], cellWidth)
                    }
                }
                renderedRows.append(renderedRow)
            }
            
            // 2. 根据列宽计算制表位 (Tab Stops)
            let paragraphStyle = NSMutableParagraphStyle()
            let columnPadding: CGFloat = 16 // 列与列之间的间距
            var tabs: [NSTextTab] = []
            var cumulativeLocation: CGFloat = 0
            
            // 我们只需要为除最后一列之外的列设置制表位
            for width in columnWidths.dropLast() {
                cumulativeLocation += width + columnPadding
                tabs.append(NSTextTab(textAlignment: .left, location: cumulativeLocation, options: [:]))
            }
            paragraphStyle.tabStops = tabs
            
            // 3. 构建最终的字符串
            for (rowIndex, renderedRow) in renderedRows.enumerated() {
                let rowString = NSMutableAttributedString()
                for (cellIndex, cellString) in renderedRow.enumerated() {
                    rowString.append(cellString)
                    
                    if cellIndex < renderedRow.count - 1 {
                        rowString.append(NSAttributedString(string: "\t"))
                    }
                }
                
                // 为首行增加上方间距，为末行增加下方间距
                let currentStyle = paragraphStyle.mutableCopy() as! NSMutableParagraphStyle
                if rowIndex == 0 {
                    currentStyle.paragraphSpacingBefore = 8
                }
                if rowIndex == renderedRows.count - 1 {
                    currentStyle.paragraphSpacing = 8
                }
                
                let range = NSRange(location: 0, length: rowString.length)
                rowString.addAttribute(.paragraphStyle, value: currentStyle, range: range)
                
                result.append(rowString)
                if rowIndex < renderedRows.count - 1 {
                    result.append(NSAttributedString(string: "\n"))
                }
            }
            return result
            
        case .taskList(_, let items):
            let result = NSMutableAttributedString()
            for (index, item) in items.enumerated() {
                let itemString = item.children.renderNSAttributedString(
                    theme: theme,
                    baseURL: baseURL,
                    softBreakMode: softBreakMode,
                    baseAttributes: blockAttributes
                )
                let marker = item.isCompleted ? "☑︎ " : "☐ "
                let markerAttr = AttributedString(marker, attributes: blockAttributes).resolvingUIStyles()
                let combined = NSMutableAttributedString(attributedString: NSAttributedString(markerAttr))
                combined.append(itemString)
                result.append(combined)
                if index < items.count - 1 {
                    result.append(NSAttributedString(string: "\n"))
                }
            }
            return result
            
        case .htmlBlock(let content):
            let attrString = AttributedString(content, attributes: blockAttributes).resolvingUIStyles()
            return NSAttributedString(attrString)
            
        case .thematicBreak:
            let breakAttr = AttributedString("---", attributes: blockAttributes).resolvingUIStyles()
            return NSAttributedString(breakAttr)
            
        default:
            // 对于不支持的块，显示其原始 Markdown 文本
            let rawMarkdown = [self].renderMarkdown()
            let attrString = AttributedString(rawMarkdown, attributes: blockAttributes).resolvingUIStyles()
            return NSAttributedString(attrString)
        }
    }
}
#endif
