import Foundation

final class OutputBuffer {
    private(set) var text = ""
    private var lineCount = 0
    private let maxLines = 5_000
    private let maxBytes = 256 * 1_024

    func append(_ chunk: String) {
        lineCount += chunk.components(separatedBy: "\n").count - 1
        text += chunk

        // Trim leading lines while over the line limit.
        while lineCount > maxLines, let nl = text.firstIndex(of: "\n") {
            text.removeSubrange(text.startIndex...nl)
            lineCount -= 1
        }

        // Hard byte cap: drop everything before the first newline past the midpoint.
        if text.utf8.count > maxBytes {
            let mid = text.index(text.startIndex, offsetBy: text.count / 2)
            if let nl = text[mid...].firstIndex(of: "\n") {
                text.removeSubrange(text.startIndex...nl)
            } else {
                text = ""
            }
            lineCount = text.components(separatedBy: "\n").count - 1
        }
    }

    func clear() { text = ""; lineCount = 0 }
}
