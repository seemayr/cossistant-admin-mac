import SwiftUI
import CossistantAdmin

struct PrototypeInfoCard<Content: View>: View {
  let title: String
  @ViewBuilder let content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(title)
        .font(.headline.weight(.semibold))

      content
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .strokeBorder(.separator.opacity(0.2), lineWidth: 1)
    }
  }
}

struct PrototypeFact: View {
  let label: String
  let value: String

  var body: some View {
    LabeledContent {
      Text(value)
        .font(.body)
        .multilineTextAlignment(.trailing)
    } label: {
      Text(label)
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
    }
  }
}
