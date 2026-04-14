import AppKit
import Foundation
import CossistantAdmin

extension String {
  var decodingHTMLEntities: String {
    guard let data = data(using: .utf8) else { return self }

    let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
      .documentType: NSAttributedString.DocumentType.html,
      .characterEncoding: String.Encoding.utf8.rawValue,
    ]

    return (try? NSAttributedString(data: data, options: options, documentAttributes: nil).string) ?? self
  }
}
