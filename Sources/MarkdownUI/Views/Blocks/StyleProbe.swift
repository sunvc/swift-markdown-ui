import SwiftUI

struct BlockStyleAttributes: Equatable {
  var textAttributes: AttributeContainer
  var margins: BlockMargin
}

struct StyleProbePreference: PreferenceKey {
  static var defaultValue: [BlockNode.BlockType: BlockStyleAttributes] = [:]
  static func reduce(
    value: inout [BlockNode.BlockType: BlockStyleAttributes],
    nextValue: () -> [BlockNode.BlockType: BlockStyleAttributes]
  ) {
    value.merge(nextValue()) { (_, new) in new }
  }
}

struct BlockStylesKey: EnvironmentKey {
    static let defaultValue: [BlockNode.BlockType: BlockStyleAttributes] = [:]
}

extension EnvironmentValues {
    var blockStyles: [BlockNode.BlockType: BlockStyleAttributes] {
        get { self[BlockStylesKey.self] }
        set { self[BlockStylesKey.self] = newValue }
    }
}

struct StyleProbe: View {
  @Environment(\.theme) private var theme

  let types: [BlockNode.BlockType]
  let onUpdate: ([BlockNode.BlockType: BlockStyleAttributes]) -> Void

  var body: some View {
    ZStack {
      ForEach(self.types, id: \.self) { type in
        ProbeItem(type: type, theme: self.theme)
      }
    }
    .onPreferenceChange(StyleProbePreference.self) { preferences in
      self.onUpdate(preferences)
    }
    .frame(width: 0, height: 0)
    .hidden()
  }
}

private struct ProbeItem: View {
  let type: BlockNode.BlockType
  let theme: Theme

  @State private var margin: BlockMargin = .unspecified

  var body: some View {
    self.applyTheme()
      .onPreferenceChange(BlockMarginsPreference.self) { value in
        self.margin = value
      }
      .transformPreference(StyleProbePreference.self) { value in
        if var attributes = value[self.type] {
          attributes.margins = self.margin
          value[self.type] = attributes
        }
      }
  }

  @ViewBuilder
  private func applyTheme() -> some View {
    switch self.type {
    case .paragraph:
      self.theme.paragraph.makeBody(
        configuration: .init(
          label: .init(ProbeInner(type: self.type)),
          content: .init(block: .paragraph(content: []))
        )
      )
    case .heading(let level):
      self.theme.headings[level - 1].makeBody(
        configuration: .init(
          label: .init(ProbeInner(type: self.type)),
          content: .init(block: .heading(level: level, content: []))
        )
      )
    // Add other types if we decide to merge them later
    default:
      EmptyView()
    }
  }
}

private struct ProbeInner: View {
  let type: BlockNode.BlockType

  var body: some View {
    TextStyleAttributesReader { attributes in
      Color.clear.preference(
        key: StyleProbePreference.self,
        value: [
          self.type: BlockStyleAttributes(
            textAttributes: attributes,
            margins: .unspecified  // Will be filled by ProbeItem
          )
        ]
      )
    }
  }
}
