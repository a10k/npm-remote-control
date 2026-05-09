import Foundation

enum Shell {
    /// Returns PATH with Homebrew and common tool dirs prepended if not already present.
    static var enrichedPath: String {
        let base = ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/bin"
        let extras = ["/usr/local/bin", "/opt/homebrew/bin", "/usr/bin", "/bin"]
        let existing = Set(base.components(separatedBy: ":"))
        let toAdd = extras.filter { !existing.contains($0) }
        return toAdd.isEmpty ? base : "\(toAdd.joined(separator: ":")):\(base)"
    }
}
