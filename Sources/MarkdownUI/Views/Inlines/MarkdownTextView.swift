import SwiftUI
#if canImport(UIKit)
import UIKit

struct TextView: UIViewRepresentable {
    @Environment(\.font) private var font
    
    // 内部存储：统一使用富文本处理
    private var attributedText: NSAttributedString

    // 允许外部传入 highlight 参数（仅当使用 String 初始化时有效）
    var highlightText: String?
    var highlightColor: UIColor = .red

    // --- 构造函数 1: 支持普通 String ---
    init(_ text: String, highlight: String? = nil, color: UIColor = .red) {
        highlightText = highlight
        highlightColor = color
        // 初始构建一次
        attributedText = Self.buildHighlightText(text, highlight: highlight, color: color)
    }

    // --- 构造函数 2: 支持直接传入 NSAttributedString ---
    init(_ attributedText: NSAttributedString) {
        self.attributedText = attributedText
        highlightText = nil
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.delegate = context.coordinator

        // 基础配置
        view.dataDetectorTypes = [.phoneNumber, .link]
        view.isScrollEnabled = false
        view.isEditable = false
        view.isUserInteractionEnabled = true
        view.isSelectable = true
        view.backgroundColor = .clear
        view.textColor = .label

        // 消除边距
        view.textContainer.lineFragmentPadding = 0
        view.textContainerInset = .zero
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        return view
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.attributedText = attributedText
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: UITextView,
        context: Context
    ) -> CGSize? {
        let targetWidth = proposal.width ?? .greatestFiniteMagnitude

        let dimensions = attributedText.boundingRect(
            with: CGSize(width: targetWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        
        // Return the calculated content size (both width and height)
        // This ensures the view shrinks to fit short text horizontally.
        return CGSize(width: ceil(dimensions.width), height: ceil(dimensions.height))
    }

    // --- 静态辅助方法：构建高亮富文本 ---
    static func buildHighlightText(_ text: String, highlight: String?, color: UIColor) -> NSAttributedString {
        let attrString = NSMutableAttributedString(string: text)
        
        // 设置默认字体（可选）
        let range = NSRange(location: 0, length: text.utf16.count)
        attrString.addAttribute(.font, value: UIFont.systemFont(ofSize: 16), range: range)
        attrString.addAttribute(.foregroundColor, value: UIColor.label, range: range)

        // 如果有高亮词，查找并标红
        if let highlight = highlight, !highlight.isEmpty {
            let nsString = text as NSString
            var searchRange = NSRange(location: 0, length: nsString.length)
            
            while searchRange.location < nsString.length {
                let foundRange = nsString.range(of: highlight, options: .caseInsensitive, range: searchRange)
                if foundRange.location == NSNotFound {
                    break
                }
                
                // 设置高亮色
                attrString.addAttribute(.foregroundColor, value: color, range: foundRange)
                
                // 更新搜索范围
                let newLocation = foundRange.location + foundRange.length
                searchRange = NSRange(location: newLocation, length: nsString.length - newLocation)
            }
        }
        
        return attrString
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: TextView

        init(_ parent: TextView) {
            self.parent = parent
        }
    }
}
#endif
