import SwiftUI
import SFSafeSymbols

struct HeaderControlLabel: View {
  let title: String
  let value: String
  let systemImage: SFSymbol

  var body: some View {
    Label {
      VStack(alignment: .leading, spacing: 1) {
        Text(title)
          .font(.caption)
          .foregroundStyle(.secondary)

        Text(value)
          .font(.subheadline.weight(.medium))
          .lineLimit(1)
      }
    } icon: {
      Image(systemSymbol: systemImage)
        .foregroundStyle(.secondary)
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 8)
    .background(.quinary, in: .rect(cornerRadius: 12))
  }
}

struct RowTag: View {
  let title: String
  var systemSymbol: SFSymbol? = nil
  let tint: Color

  var body: some View {
    Label {
      Text(title)
    } icon: {
      if let systemSymbol {
        Image(systemSymbol: systemSymbol)
      }
    }
    .labelStyle(.titleAndIcon)
    .font(.caption2.weight(.semibold))
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(tint.opacity(0.12), in: .capsule)
    .foregroundStyle(tint)
  }
}
