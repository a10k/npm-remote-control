import Foundation

enum ScriptState: Equatable {
    case idle
    case running(pid: Int32, startedAt: Date)
    case exited(code: Int32, at: Date)
}

struct Script: Identifiable, Hashable {
    let id: String      // script name (key in package.json)
    let command: String // raw command string
}

struct PackageJSON {
    let name: String?
    let scripts: [Script] // ordered as they appear in the file
}

extension PackageJSON {
    enum ParseError: Error, LocalizedError {
        case notAnObject
        var errorDescription: String? { "package.json root is not a JSON object" }
    }

    static func parse(from data: Data) throws -> PackageJSON {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ParseError.notAnObject
        }
        let name = root["name"] as? String
        let scriptValues = root["scripts"] as? [String: String] ?? [:]

        // Recover insertion order from raw bytes; JSONSerialization uses NSDictionary (unordered).
        let orderedKeys = scriptKeyOrder(in: data)

        var seen = Set<String>()
        var scripts: [Script] = []
        for key in orderedKeys {
            guard let cmd = scriptValues[key], !seen.contains(key) else { continue }
            scripts.append(Script(id: key, command: cmd))
            seen.insert(key)
        }
        // Defensive: append anything the scanner missed (shouldn't happen for valid package.json).
        for key in scriptValues.keys.sorted() where !seen.contains(key) {
            scripts.append(Script(id: key, command: scriptValues[key]!))
        }
        return PackageJSON(name: name, scripts: scripts)
    }

    // Walk the raw UTF-8 text to pull "scripts" keys in the order they appear.
    private static func scriptKeyOrder(in data: Data) -> [String] {
        guard let text = String(data: data, encoding: .utf8) else { return [] }
        var i = text.startIndex

        guard let scriptsRange = text.range(of: "\"scripts\"") else { return [] }
        i = scriptsRange.upperBound
        advance(&i, in: text, past: ":")
        advance(&i, in: text, past: "{")

        var keys: [String] = []
        while i < text.endIndex {
            skipWhitespaceAndCommas(&i, in: text)
            guard i < text.endIndex, text[i] != "}" else { break }
            if text[i] == "\"" {
                i = text.index(after: i)
                keys.append(readJSONString(&i, in: text))
                advance(&i, in: text, past: ":")
                skipJSONStringValue(&i, in: text)
            } else {
                i = text.index(after: i)
            }
        }
        return keys
    }

    private static func advance(_ i: inout String.Index, in text: String, past target: Character) {
        while i < text.endIndex, text[i] != target { i = text.index(after: i) }
        if i < text.endIndex { i = text.index(after: i) }
    }

    private static func skipWhitespaceAndCommas(_ i: inout String.Index, in text: String) {
        while i < text.endIndex {
            let c = text[i]
            guard c == " " || c == "\n" || c == "\r" || c == "\t" || c == "," else { break }
            i = text.index(after: i)
        }
    }

    // i is positioned just after the opening '"'; reads until unescaped '"' and advances past it.
    private static func readJSONString(_ i: inout String.Index, in text: String) -> String {
        let start = i
        while i < text.endIndex {
            if text[i] == "\\" {
                i = text.index(after: i)
                if i < text.endIndex { i = text.index(after: i) }
            } else if text[i] == "\"" {
                let s = String(text[start..<i])
                i = text.index(after: i)
                return s
            } else {
                i = text.index(after: i)
            }
        }
        return String(text[start...])
    }

    // Skip whitespace then a quoted string value; i ends up after the closing '"'.
    private static func skipJSONStringValue(_ i: inout String.Index, in text: String) {
        while i < text.endIndex {
            let c = text[i]
            guard c == " " || c == "\n" || c == "\r" || c == "\t" else { break }
            i = text.index(after: i)
        }
        guard i < text.endIndex, text[i] == "\"" else { return }
        i = text.index(after: i)
        while i < text.endIndex {
            if text[i] == "\\" {
                i = text.index(after: i)
                if i < text.endIndex { i = text.index(after: i) }
            } else if text[i] == "\"" {
                i = text.index(after: i)
                return
            } else {
                i = text.index(after: i)
            }
        }
    }
}
