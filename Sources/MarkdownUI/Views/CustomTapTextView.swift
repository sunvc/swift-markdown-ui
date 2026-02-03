#if canImport(UIKit)
import SwiftUI
import UIKit

public class CustomTapTextView: UITextView, UIGestureRecognizerDelegate {
    private lazy var tapGesture = UITapGestureRecognizer(target: self, action: #selector(tap))
    private let doubleTapGesture = UITapGestureRecognizer()
    private var linkTapGesture: UIGestureRecognizer?
    public var customTapAction: (() -> Void)?

    public init() {
        super.init(frame: .zero, textContainer: nil)

        self.backgroundColor = UIColor.clear
        self.isEditable = false
        self.dataDetectorTypes = [.phoneNumber, .link]
        self.isScrollEnabled = false
        self.textContainerInset = .zero
        self.textContainer.lineFragmentPadding = 0
        self.textContainer.lineBreakMode = .byWordWrapping
        self.setContentHuggingPriority(.required, for: .vertical)
        self.setContentCompressionResistancePriority(.required, for: .vertical)

        tapGesture.delegate = self
        self.addGestureRecognizer(tapGesture)

        self.linkTapGesture = self.gestureRecognizers?
            .first { $0 is UITapGestureRecognizer && $0.name == "UITextInteractionNameLinkTap" }

        doubleTapGesture.numberOfTapsRequired = 2
        doubleTapGesture.delegate = self
        self.addGestureRecognizer(doubleTapGesture)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc func tap() {
        self.customTapAction?()
    }

    public override func copy(_ sender: Any?) {
        super.copy(sender)
        // 复制完成后清除选中范围
        self.selectedRange = NSRange(location: 0, length: 0)
    }

    public func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        if gestureRecognizer == doubleTapGesture {
            return true
        }
        return false
    }

    public override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer)
        -> Bool
    {
        if gestureRecognizer == tapGesture {
            if self.selectedRange.length > 0 {
                return false
            }
        }
        return super.gestureRecognizerShouldBegin(gestureRecognizer)
    }

    public func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        if gestureRecognizer == tapGesture {
            if otherGestureRecognizer == doubleTapGesture {
                return true
            }
            if otherGestureRecognizer == linkTapGesture {
                return true
            }
        }
        return false
    }
}

struct CustomTapTextViewRepresentable: UIViewRepresentable {
    let attributedString: NSAttributedString
    var customTapAction: (() -> Void)?
    var lineLimit: Int?

    func makeUIView(context: Context) -> CustomTapTextView {
        let textView = CustomTapTextView()
        textView.customTapAction = customTapAction
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.setContentCompressionResistancePriority(.required, for: .vertical)
        return textView
    }

    func updateUIView(_ uiView: CustomTapTextView, context: Context) {
        uiView.attributedText = attributedString
        uiView.customTapAction = customTapAction
        
        // 应用行数限制
        if let lineLimit = lineLimit {
            uiView.textContainer.maximumNumberOfLines = lineLimit
            uiView.textContainer.lineBreakMode = .byTruncatingTail
        } else {
            uiView.textContainer.maximumNumberOfLines = 0
            uiView.textContainer.lineBreakMode = .byWordWrapping
        }
    }

    @available(iOS 16.0, *)
    func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: CustomTapTextView,
        context: Context
    ) -> CGSize? {
        let width = proposal.width ?? .greatestFiniteMagnitude
        let size = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return size
    }
}
#endif
