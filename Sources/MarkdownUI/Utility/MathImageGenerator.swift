import SwiftUI
import SwiftUIMath

#if os(macOS)
import AppKit
#else
import UIKit
#endif

@MainActor
enum MathImageGenerator {
  static func image(for latex: String, fontSize: CGFloat, color: Color?) -> Image? {
    let mathView = Math(latex)
      .mathFont(.init(name: .latinModern, size: fontSize))
      .foregroundStyle(color ?? .primary)
      .mathTypesettingStyle(.text) // Inline math style
    
    let renderer = ImageRenderer(content: mathView)
    
    #if os(macOS)
    renderer.scale = NSScreen.main?.backingScaleFactor ?? 2.0
    #else
    renderer.scale = UIScreen.main.scale
    #endif
    
    // Transparent background
    #if os(macOS)
    renderer.isOpaque = false // Not available on macOS ImageRenderer? Check docs.
    // macOS ImageRenderer usually produces transparent background by default if view is transparent.
    #else
    renderer.isOpaque = false
    #endif

    #if os(macOS)
    if let nsImage = renderer.nsImage {
      return Image(nsImage: nsImage)
    }
    #else
    if let uiImage = renderer.uiImage {
      return Image(uiImage: uiImage)
    }
    #endif
    
    return nil
  }
}
