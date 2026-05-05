import Foundation

do {
    if let located = ProjectLocator.findPackageJSON() {
        let data = try Data(contentsOf: located.file)
        let pkg = try PackageJSON.parse(from: data)
        print("Project: \(pkg.name ?? "(unnamed)")")
        print("Scripts (\(pkg.scripts.count)):")
        for script in pkg.scripts {
            print("  \(script.id): \(script.command)")
        }
    } else {
        print("No package.json found next to this app. Drop the app into an npm project folder.")
    }
} catch {
    print("Error: \(error.localizedDescription)")
}
