import SwiftUI
#if canImport(UIKit)
import UIKit

extension FontProperties {
    func resolveUIFont() -> UIFont {
        var fontDescriptor: UIFontDescriptor
        
        switch self.family {
        case .system(let design):
            var systemDesign: UIFontDescriptor.SystemDesign = .default
            switch design {
            case .serif: systemDesign = .serif
            case .monospaced: systemDesign = .monospaced
            case .rounded: systemDesign = .rounded
            default: break
            }
            
            // Start with system font of specific weight to get the right descriptor
            let systemFont = UIFont.systemFont(ofSize: self.scaledSize, weight: self.uiFontWeight)
            fontDescriptor = systemFont.fontDescriptor.withDesign(systemDesign) ?? systemFont.fontDescriptor
            
        case .custom(let name):
            fontDescriptor = UIFontDescriptor(name: name, size: self.scaledSize)
        }
        
        // Traits
        var traits: UIFontDescriptor.SymbolicTraits = []
        if self.style == .italic {
            traits.insert(.traitItalic)
        }
        // Mapping generic bold trait if possible, though weight usually handles it.
        // UIFontDescriptor doesn't strictly separate weight from traits in all cases, but weight property is better.
        
        traits.formUnion(fontDescriptor.symbolicTraits)
        fontDescriptor = fontDescriptor.withSymbolicTraits(traits) ?? fontDescriptor
        
        // Apply Feature Settings (Small Caps, etc.)
        // This is complex in UIKit. We'll use a simplified approach or skip if too complex for this turn.
        // But user wants "Maintain original font".
        // Let's apply at least the weight and size correctly.
        
        // Re-apply weight to descriptor to be sure (if custom font didn't have it)
        let traitsAttribute: [UIFontDescriptor.TraitKey: Any] = [
            .weight: self.uiFontWeight
        ]
        var fontAttributes = fontDescriptor.fontAttributes
        fontAttributes[.traits] = traitsAttribute
        fontDescriptor = UIFontDescriptor(fontAttributes: fontAttributes)

        return UIFont(descriptor: fontDescriptor, size: self.scaledSize)
    }
    
    var uiFontWeight: UIFont.Weight {
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

extension AttributedString {
    func resolvingUIFonts() -> NSAttributedString {
        // Create a mutable copy.
        // Note: converting directly to NSMutableAttributedString might not preserve SwiftUI attributes 
        // that don't map to standard NSAttributes.
        // But we are specifically handling FontProperties and Color here.
        
        let nsStr: NSMutableAttributedString
        do {
            nsStr = try NSMutableAttributedString(self, including: \.uiKit)
        } catch {
             // Fallback if conversion fails (unlikely for simple text)
            nsStr = NSMutableAttributedString(string: String(self.characters))
        }
        
        // We manually re-apply properties because the automatic conversion might miss our custom keys 
        // or not map SwiftUI Font/Color exactly how we want if they are not standard.
        // Especially FontProperties is custom and definitely won't be mapped.
        
        for run in self.runs {
            let range = NSRange(run.range, in: self)
            
            // Font
            if let fontProps = run.fontProperties {
                let uiFont = fontProps.resolveUIFont()
                nsStr.addAttribute(.font, value: uiFont, range: range)
            }
            
            // Colors - try to ensure they are UIColor
            // We explicitly use SwiftUI attributes because the source AttributedString was created with them.
            if let color = run.swiftUI.foregroundColor {
                nsStr.addAttribute(.foregroundColor, value: UIColor(color), range: range)
            } else if run.link == nil {
                // If no explicit color is set and it's not a link, use the system label color
                // to ensure it adapts to Light/Dark mode.
                nsStr.addAttribute(.foregroundColor, value: UIColor.label, range: range)
            }
            
            if let bgColor = run.swiftUI.backgroundColor {
                nsStr.addAttribute(.backgroundColor, value: UIColor(bgColor), range: range)
            }
            
            // Strikethrough
            if let style = run.strikethroughStyle {
                // Map NSUnderlineStyle... simpler to just set .strikethroughStyle
                // SwiftUI StrikethroughStyle is distinct.
                // We'll just assume single line for now as common case
                nsStr.addAttribute(.strikethroughStyle, value: style, range: range)
            }
            
            // Underline
            if let style = run.underlineStyle {
                nsStr.addAttribute(.underlineStyle, value: style, range: range)
            }
            
            // Link
            if let link = run.link {
                nsStr.addAttribute(.link, value: link, range: range)
            }
        }
        
        return nsStr
    }
}
#endif
