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
        TextView(attributedText: attributedText)
            .fixedSize(horizontal: false, vertical: true)
        #elseif os(macOS)
        Text(AttributedString(attributedText))
            .fixedSize(horizontal: false, vertical: true)
        #else
        EmptyView()
        #endif
    }

    private var attributedText: NSAttributedString {
        let result = NSMutableAttributedString()
        appendBlocks(blocks, to: result, indentLevel: 0)
        return result
    }

    private func appendBlocks(
        _ blocks: [BlockNode],
        to result: NSMutableAttributedString,
        indentLevel: Int,
        inheritedAttributes: AttributeContainer? = nil
    ) {
        for (index, block) in blocks.enumerated() {
            appendBlock(
                block,
                to: result,
                indentLevel: indentLevel,
                isLast: index == blocks.count - 1,
                nextBlock: index < blocks.count - 1 ? blocks[index + 1] : nil,
                inheritedAttributes: inheritedAttributes
            )
        }
    }

    private func appendBlock(
        _ block: BlockNode,
        to result: NSMutableAttributedString,
        indentLevel: Int,
        isLast: Bool,
        nextBlock: BlockNode?,
        overrideSpacing: CGFloat? = nil,
        inheritedAttributes: AttributeContainer? = nil
    ) {
        // Determine styles
        let type = block.blockType ?? .paragraph // fallback
        let attributes = styles[type] ?? styles[.paragraph] // fallback

        // Merge attributes
        var combinedAttributes = inheritedAttributes ?? AttributeContainer()
        if let blockAttributes = attributes?.textAttributes {
            combinedAttributes.merge(blockAttributes)
        }

        // Spacing Calculation
        let thisBottom = attributes?.margins.bottom ?? 0
        var spacing: CGFloat = thisBottom

        if let override = overrideSpacing {
            spacing = override
        } else if let nextBlock = nextBlock,
                  let nextType = nextBlock.blockType,
                  let nextAttributes = styles[nextType]
        {
            let nextTop = nextAttributes.margins.top ?? 0
            spacing = max(thisBottom, nextTop)
        }

        // Adjust font size if theme attributes are missing (e.g. List usually doesn't set font,
        // Paragraph does)
        // If attributes is nil or empty text attributes, try to use Paragraph attributes as base
        // for text content?
        // Actually, usually we want to inherit.

        // For lists, we often don't get text attributes from the List style itself.
        // We should fallback to paragraph attributes for the content of the list if needed.
        // But `appendContent` will use passed `attributes`.

        switch block {
        case .paragraph(let content), .heading(_, let content):
            var localAttributes = inheritedAttributes ?? AttributeContainer()
            if let blockAttributes = attributes?.textAttributes {
                localAttributes.merge(blockAttributes)
            }
            appendContent(
                content,
                to: result,
                spacing: spacing,
                indentLevel: indentLevel,
                attributes: localAttributes
            )

        case .blockquote(let children):
            // Indent level increases
            // 引用单独处理
            var quoteAttributes = inheritedAttributes ?? AttributeContainer()
            if let quoteStyle = styles[.blockquote]?.textAttributes {
                quoteAttributes.merge(quoteStyle)
            }
            appendBlocks(children, to: result, indentLevel: indentLevel + 1, inheritedAttributes: quoteAttributes)

        case .bulletedList(let isTight, let items):
            var listAttributes = inheritedAttributes ?? AttributeContainer()
            if let blockAttributes = attributes?.textAttributes {
                listAttributes.merge(blockAttributes)
            }
            appendListItems(
                items,
                style: .bullet,
                isTight: isTight,
                to: result,
                indentLevel: indentLevel,
                spacing: spacing,
                attributes: listAttributes
            )

        case .numberedList(let isTight, let start, let items):
            var listAttributes = inheritedAttributes ?? AttributeContainer()
            if let blockAttributes = attributes?.textAttributes {
                listAttributes.merge(blockAttributes)
            }
            appendListItems(
                items,
                style: .number(start: start),
                isTight: isTight,
                to: result,
                indentLevel: indentLevel,
                spacing: spacing,
                attributes: listAttributes
            )

        case .taskList(let isTight, let items):
            var listAttributes = inheritedAttributes ?? AttributeContainer()
            if let blockAttributes = attributes?.textAttributes {
                listAttributes.merge(blockAttributes)
            }
            appendListItems(
                items,
                style: .task,
                isTight: isTight,
                to: result,
                indentLevel: indentLevel,
                spacing: spacing,
                attributes: listAttributes
            )

        default:
            break // Should not happen if coalescing logic is correct
        }

        // Add newline if not last in this sequence
        if !isLast {
            // CRITICAL FIX: The newline must carry the paragraph style (spacing/indent) of the
            // preceding block
            // to ensure the spacing is actually rendered by UITextView.
            // We reuse the attributes calculated for the block content if possible, or at least the
            // spacing.

            let pStyle = NSMutableParagraphStyle()
            pStyle.paragraphSpacing = spacing
            // We might need to match indentation of the *next* block?
            // Or the current? Paragraph spacing applies to the gap *after* the newline.
            // So it belongs to the current block.

            // We should try to capture the attributes used in the switch cases to apply here.
            // But `appendContent` creates its own pStyle internally.

            // Simplified approach: Create a newline with the correct spacing.
            let newline = NSMutableAttributedString(string: "\n")
            newline.addAttribute(
                NSAttributedString.Key.paragraphStyle,
                value: pStyle,
                range: NSRange(location: 0, length: 1)
            )
            result.append(newline)
        }
    }

    enum ListStyle {
        case bullet
        case number(start: Int)
        case task
    }

    private func appendListItems<T>(
        _ items: [T],
        style: ListStyle,
        isTight: Bool,
        to result: NSMutableAttributedString,
        indentLevel: Int,
        spacing: CGFloat,
        attributes: AttributeContainer?
    ) {
        // Use listItem attributes for content to ensure specific list styling is respected
        let listItemType = BlockNode.BlockType.listItem
        let listItemAttributes = styles[listItemType]
        
        var combinedItemAttributes = attributes ?? AttributeContainer()
        if let liAttrs = listItemAttributes?.textAttributes {
            combinedItemAttributes.merge(liAttrs)
        }

        // Basic Theme defaults:
        // listItem top margin = 0.25em (~4.25pt at 17pt)
        // paragraph bottom margin = 1em (~17pt)
        let defaultFontSize = FontProperties.defaultSize
        let defaultListItemTop = defaultFontSize * 0.5
        let defaultParagraphBottom = defaultFontSize * 1.0

        let listItemTopMargin = listItemAttributes?.margins.top ?? defaultListItemTop

        // Calculate Indentation based on Font Size
        // Use the font size from the list item itself, or fallback to paragraph/default
        let contentFontProperties = combinedItemAttributes.fontProperties ?? styles[.paragraph]?.textAttributes.fontProperties
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
            let pBottom = styles[.paragraph]?.margins.bottom ?? defaultParagraphBottom
            let standardSpacing = isTight ? listItemTopMargin : max(pBottom, listItemTopMargin)

            let itemSpacing: CGFloat = (index == items.count - 1) ? spacing : standardSpacing

            // 修改类型定义
            let markerAttrStr = NSMutableAttributedString()

            // 统一样式配置函数
            func getMarkerAttributes(
                size: CGFloat,
                offset: CGFloat,
                padding: CGFloat = 6 // 增加 padding 参数
            ) -> [NSAttributedString.Key: Any] {
                return [
                    .font: UIFont.systemFont(ofSize: size, weight: .medium),
                    .baselineOffset: offset,
                    .foregroundColor: UIColor.label,
                    .kern: padding // 设置字间距，这会直接增加数字或符号后的空隙
                ]
            }
            
            func createMarkerImage(size: CGFloat, isHollow: Bool, isSquare: Bool = false, padding: CGFloat = 5) -> UIImage {
                // 图片的总宽度 = 形状大小 + 你想要的间距
                let totalSize = CGSize(width: size + padding, height: size)
                let renderer = UIGraphicsImageRenderer(size: totalSize)
                
                return renderer.image { context in
                    // 形状绘制在左侧，x: 1 留一点抗锯齿空间
                    let rect = CGRect(x: 1, y: 1, width: size - 2, height: size - 2)
                    let path = isSquare ? UIBezierPath(rect: rect) : UIBezierPath(ovalIn: rect)
                    
                    UIColor.label.set()
                    if isHollow {
                        path.lineWidth = 1.2
                        path.stroke()
                    } else {
                        path.fill()
                    }
                    // 右侧的 padding 区域会自动保持透明
                }
            }
            
            func getAttributedString(forImage image: UIImage, font: UIFont) -> NSAttributedString {
                let attachment = NSTextAttachment()
                attachment.image = image
                
                let yOffset = (font.capHeight - image.size.height) / 2
                attachment.bounds = CGRect(x: 0, y: yOffset, width: image.size.width, height: image.size.height)
                
                return NSAttributedString(attachment: attachment)
            }
            
            let currentFont: UIFont
            if let fontProp = contentFontProperties {
                currentFont = fontProp.resolveUIFont()
            } else {
                currentFont = UIFont.systemFont(ofSize: fontSize)
            }

            switch style {
            case .bullet:
                let level = indentLevel + 1
                if level == 1 {
              
                    let img = createMarkerImage(size: 10, isHollow: false)
                    markerAttrStr.append(getAttributedString(forImage: img, font: currentFont))
                } else if level == 2 {
             
                    let img = createMarkerImage(size: 8, isHollow: true)
                    markerAttrStr.append(getAttributedString(forImage: img, font: currentFont))
                } else {
          
                    let img = createMarkerImage(size: 7, isHollow: false, isSquare: true)
                    markerAttrStr.append(getAttributedString(forImage: img, font: currentFont))
                }

            case .number(let start):
           
                let attrs = getMarkerAttributes(size: 17, offset: 1)
                markerAttrStr.append(NSAttributedString(
                    string: "\(start + index).",
                    attributes: attrs
                ))

            case .task:
                // 任务框通常比文字矮，上移 1-2pt 会更好看
                let attrs = getMarkerAttributes(size: 18, offset: -1)
                markerAttrStr.append(NSAttributedString(
                    string: isCompleted ? "☑" : "☐",
                    attributes: attrs
                ))
            }

            // Indentation logic
            let baseIndent = CGFloat(indentLevel) * indentUnit
            let itemIndent: CGFloat = indentUnit

            let pStyle = NSMutableParagraphStyle()
            pStyle.firstLineHeadIndent = baseIndent
            pStyle.headIndent = baseIndent + itemIndent

            // Determine spacing for the first block (merged with marker)
            // If the marker paragraph is the first character, its style dictates the paragraph
            // spacing.
            // If the item has only 1 child, use itemSpacing.
            // If it has multiple, use internal paragraph spacing (usually paragraph bottom margin).
            let firstBlockSpacing = (children.count == 1) ? itemSpacing : standardSpacing
            pStyle.paragraphSpacing = firstBlockSpacing

            pStyle.tabStops = [NSTextTab(
                textAlignment: .left,
                location: baseIndent + itemIndent,
                options: [:]
            )]

            markerAttrStr.addAttribute(
                NSAttributedString.Key.paragraphStyle,
                value: pStyle,
                range: NSRange(location: 0, length: markerAttrStr.length)
            )
            // Use standard label color for marker to avoid it disappearing if list item text has
            // peculiar color,
            // OR match list item text color? Usually matching text is better.
            // But user complained "did not achieve effect".
            // Let's use the listItemAttributes for marker too.
            if let color = combinedItemAttributes.foregroundColor {
                markerAttrStr.addAttribute(
                    NSAttributedString.Key.foregroundColor,
                    value: UIColor(color),
                    range: NSRange(location: 0, length: markerAttrStr.length)
                )
            } else {
                markerAttrStr.addAttribute(
                    NSAttributedString.Key.foregroundColor,
                    value: UIColor.label,
                    range: NSRange(location: 0, length: markerAttrStr.length)
                )
            }

            // Apply font
            if let fontProp = contentFontProperties {
                let uiFont = fontProp.resolveUIFont()
                markerAttrStr.addAttribute(
                    .font,
                    value: uiFont,
                    range: NSRange(location: 0, length: markerAttrStr.length)
                )
            }

            result.append(markerAttrStr)

            for (childIndex, child) in children.enumerated() {
                if childIndex == 0 {
                    if case .paragraph(let c) = child {
                        // CRITICAL FIX: Use listItemAttributes for content
                        appendContent(
                            c,
                            to: result,
                            spacing: firstBlockSpacing,
                            indentLevel: indentLevel,
                            overrideParagraphStyle: pStyle,
                            attributes: combinedItemAttributes,
                            indentUnit: indentUnit
                        )
                    } else {
                        let newline = NSMutableAttributedString(string: "\n")
                        newline.addAttribute(
                            NSAttributedString.Key.paragraphStyle,
                            value: pStyle,
                            range: NSRange(location: 0, length: 1)
                        )
                        result.append(newline)
                        appendBlock(
                            child,
                            to: result,
                            indentLevel: indentLevel + 1,
                            isLast: childIndex == children.count - 1,
                            nextBlock: nil,
                            overrideSpacing: (childIndex == children.count - 1) ? itemSpacing : nil,
                            inheritedAttributes: combinedItemAttributes
                        )
                    }
                } else {
                    let newline = NSMutableAttributedString(string: "\n")
                    // This intermediate newline should probably have 0 spacing if we are inside an
                    // item?
                    // Or should it have itemSpacing if it separates blocks?
                    // Usually 0.
                    let interBlockStyle = pStyle.mutableCopy() as! NSMutableParagraphStyle
                    interBlockStyle.paragraphSpacing = 0
                    newline.addAttribute(
                        NSAttributedString.Key.paragraphStyle,
                        value: interBlockStyle,
                        range: NSRange(location: 0, length: 1)
                    )
                    result.append(newline)

                    appendBlock(
                        child,
                        to: result,
                        indentLevel: indentLevel + 1,
                        isLast: childIndex == children.count - 1,
                        nextBlock: nil,
                        overrideSpacing: (childIndex == children.count - 1) ? itemSpacing : nil,
                        inheritedAttributes: combinedItemAttributes
                    )
                }
            }

            if index < items.count - 1 {
                // Newline between list items
                // It must carry the spacing of the CURRENT item (itemSpacing) to separate it from
                // the next.
                let newline = NSMutableAttributedString(string: "\n")
                let spacingStyle = NSMutableParagraphStyle()
                spacingStyle.paragraphSpacing = itemSpacing
                // Indent? Does not matter for empty newline, but good for consistency.
                spacingStyle.firstLineHeadIndent = baseIndent
                spacingStyle.headIndent = baseIndent

                newline.addAttribute(
                    NSAttributedString.Key.paragraphStyle,
                    value: spacingStyle,
                    range: NSRange(location: 0, length: 1)
                )
                result.append(newline)
            }
        }
    }

    private func appendContent(
        _ content: [InlineNode],
        to result: NSMutableAttributedString,
        spacing: CGFloat,
        indentLevel: Int,
        overrideParagraphStyle: NSMutableParagraphStyle? = nil,
        attributes: AttributeContainer?,
        indentUnit: CGFloat = 20.0
    ) {
        let textStyles = InlineTextStyles(
            code: theme.code,
            emphasis: theme.emphasis,
            strong: theme.strong,
            strikethrough: theme.strikethrough,
            link: theme.link
        )

        let attrStr = content.renderAttributedString(
            baseURL: baseURL,
            textStyles: textStyles,
            softBreakMode: softBreakMode,
            attributes: attributes ?? AttributeContainer(), // Use passed attributes or empty
            colorScheme: colorScheme
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
        nsAttrStr.enumerateAttribute(
            NSAttributedString.Key.paragraphStyle,
            in: fullRange,
            options: []
        ) { value, range, _ in
            let existing = (value as? NSParagraphStyle)?
                .mutableCopy() as? NSMutableParagraphStyle ?? pStyle
                .mutableCopy() as! NSMutableParagraphStyle
            // Merge properties
            existing.firstLineHeadIndent = pStyle.firstLineHeadIndent
            existing.headIndent = pStyle.headIndent
            existing.paragraphSpacing = pStyle.paragraphSpacing
            // Keep existing tab stops?
            if !pStyle.tabStops.isEmpty {
                existing.tabStops = pStyle.tabStops
            }
            nsAttrStr.addAttribute(
                NSAttributedString.Key.paragraphStyle,
                value: existing,
                range: range
            )
        }

        if nsAttrStr.length > 0 {
            // Ensure base pStyle is applied if missing
            // But enumeration covers it.
            // Just in case whole string has no pStyle:
            nsAttrStr.addAttributes(
                [NSAttributedString.Key.paragraphStyle: pStyle],
                range: fullRange
            )
        }

        result.append(nsAttrStr)
    }
}
