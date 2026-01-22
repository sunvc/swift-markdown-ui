import SwiftUI
#if canImport(UIKit)
import UIKit

struct TextView: UIViewRepresentable {
    @Environment(\.font) private var font
    @Environment(\.menus) private var menus

    var attributedText: NSAttributedString
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> AutoDeselectTextView {
        let view = AutoDeselectTextView()
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

    func updateUIView(_ uiView: AutoDeselectTextView, context: Context) {
        uiView.attributedText = attributedText
        uiView.menuElements = menus
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: AutoDeselectTextView,
        context: Context
    ) -> CGSize? {
        let maxWidth = proposal.width ?? .greatestFiniteMagnitude

        let unconstrained = attributedText.boundingRect(
            with: CGSize(width: .greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )

        let width = min(ceil(unconstrained.width), maxWidth)

        let constrained = attributedText.boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )

        return CGSize(
            width: width,
            height: ceil(constrained.height)
        )
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: TextView

        init(_ parent: TextView) {
            self.parent = parent
        }
    }
}

final class AutoDeselectTextView: UITextView {
    var menuElements: [UIMenuElement] = []
    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func copy(_ sender: Any?) {
        super.copy(sender)
        clearSelection()
    }

    override func editMenu(
        for textRange: UITextRange,
        suggestedActions: [UIMenuElement]
    ) -> UIMenu? {
        return UIMenu(children: menuElements + suggestedActions)
    }

    private func clearSelection() {
        DispatchQueue.main.async {
            self.selectedRange = NSRange(location: 0, length: 0)
            self.resignFirstResponder()
        }
    }
}

#endif
