import SwiftUI
#if canImport(UIKit)
import UIKit

struct TextView: UIViewRepresentable {
    @Environment(\.font) private var font

    var attributedText: NSAttributedString

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UITextView {
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

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: TextView

        init(_ parent: TextView) {
            self.parent = parent
        }
    }
}

final class AutoDeselectTextView: UITextView, UIEditMenuInteractionDelegate {
    private lazy var editMenuInteraction = UIEditMenuInteraction(delegate: self)

    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func editMenu(
        for textRange: UITextRange,
        suggestedActions: [UIMenuElement]
    ) -> UIMenu? {
        let copy = UIAction(title: "复制") { _ in
            let range = self.selectedRange
            guard range.length > 0 else { return }

            UIPasteboard.general.string =
                (self.text as NSString).substring(with: range)

            self.selectedRange = NSRange(location: 0, length: 0)
            self.resignFirstResponder()
        }

        return UIMenu(children: [copy, copy, copy])
    }

    private func clearSelection() {
        DispatchQueue.main.async {
            self.selectedRange = NSRange(location: 0, length: 0)
            self.resignFirstResponder()
        }
    }
}

#endif
