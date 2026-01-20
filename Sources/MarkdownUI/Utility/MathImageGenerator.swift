import SwiftUI
import SwiftUIMath

#if os(macOS)
import AppKit
#else
import UIKit
#endif

@MainActor
enum MathImageGenerator {
  #if os(macOS)
  typealias PlatformImage = NSImage
  #else
  typealias PlatformImage = UIImage
  #endif

  static func image(
    for latex: String,
    fontSize: CGFloat,
    weight: Font.Weight,
    color: Color?,
    colorScheme: ColorScheme
  ) -> Image? {
    guard let platformImage = platformImage(
      for: latex,
      fontSize: fontSize,
      weight: weight,
      color: color,
      colorScheme: colorScheme
    ) else {
      return nil
    }

    #if os(macOS)
    return Image(nsImage: platformImage)
    #else
    return Image(uiImage: platformImage)
    #endif
  }

  static func platformImage(
    for latex: String,
    fontSize: CGFloat,
    weight: Font.Weight,
    color: Color?,
    colorScheme: ColorScheme
  ) -> PlatformImage? {
    // If weight is bold, we might want to adjust the font or use a modifier.
    // SwiftUIMath doesn't strictly support SwiftUI font weights in all cases,
    // but we can try applying the environment or using a bold font if available.
    // For now, we rely on SwiftUI's environment propagation.
    
    let cleanLatex = latex.trimmingCharacters(in: .whitespacesAndNewlines)
    let isDisplayMath = cleanLatex.contains("\\begin") || cleanLatex.contains("\\\\") || cleanLatex.contains("\n")
    
    let mathView = Math(cleanLatex)
      .mathFont(.init(name: .latinModern, size: fontSize))
      .foregroundStyle(color ?? .primary)
      .mathTypesettingStyle(isDisplayMath ? .display : .text)
      .environment(\.colorScheme, colorScheme)

    let renderer = ImageRenderer(content: mathView)

    #if os(macOS)
    renderer.scale = NSScreen.main?.backingScaleFactor ?? 2.0
    #else
    renderer.scale = UIScreen.main.scale
    #endif

    // Transparent background
    #if os(macOS)
    // renderer.isOpaque = false // Not available on macOS ImageRenderer?
    #else
    renderer.isOpaque = false
    #endif

    #if os(macOS)
    return renderer.nsImage
    #else
    return renderer.uiImage
    #endif
  }
}
