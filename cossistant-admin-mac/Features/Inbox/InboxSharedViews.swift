import SwiftUI
import SFSafeSymbols
import CossistantAdmin

struct HeaderControlLabel: View {
  let title: String
  let value: String
  let systemImage: SFSymbol

  var body: some View {
    Label(value, systemSymbol: systemImage)
      .font(.caption.weight(.medium))
      .lineLimit(1)
      .truncationMode(.tail)
      .padding(.horizontal, 9)
      .padding(.vertical, 5)
      .background(.quinary.opacity(0.8), in: .rect(cornerRadius: 7))
      .help(title)
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
    .background(tint.opacity(0.12), in: .rect(cornerRadius: 6))
    .foregroundStyle(tint)
  }
}
