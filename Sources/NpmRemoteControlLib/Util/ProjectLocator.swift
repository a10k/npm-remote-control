import Foundation

enum ProjectLocator {
    struct Result {
        let file: URL
        let directory: URL
    }

    /// Resolution order:
    /// 1. Folder containing the .app bundle (production use).
    /// 2. Current working directory (swift run / dev).
    static func findPackageJSON() -> Result? {
        let bundleParent = Bundle.main.bundleURL.deletingLastPathComponent()
        if let r = check(bundleParent) { return r }

        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        if let r = check(cwd) { return r }

        return nil
    }

    private static func check(_ dir: URL) -> Result? {
        let candidate = dir.appendingPathComponent("package.json")
        guard FileManager.default.fileExists(atPath: candidate.path) else { return nil }
        return Result(file: candidate, directory: dir)
    }
}
