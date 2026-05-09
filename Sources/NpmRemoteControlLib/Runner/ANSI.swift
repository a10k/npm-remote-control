import Foundation

enum ANSI {
    // CSI sequences (\e[…m), OSC sequences (\e]…BEL), designate-charset (\e( or \e)), lone escapes.
    private static let regex = try! NSRegularExpression(
        pattern: #"\x1b(?:\[[0-9;]*[A-Za-z]|\][^\x07]*\x07|[()][0-2AB]|.)"#
    )

    static func strip(_ s: String) -> String {
        let r = NSRange(s.startIndex..., in: s)
        return regex.stringByReplacingMatches(in: s, range: r, withTemplate: "")
    }
}
