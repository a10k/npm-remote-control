import Foundation

/// Watches a single file for changes via DispatchSource.
/// Re-establishes the watch on rename/delete so atomic saves
/// (write-to-temp then rename, used by VS Code, vim, etc.) are caught.
final class FileWatcher {
    private var source: DispatchSourceFileSystemObject?

    func watch(_ url: URL, onChange: @escaping () -> Void) {
        stop()
        let fd = open(url.path, O_EVTONLY)
        guard fd != -1 else { return }

        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete],
            queue: .main
        )

        src.setEventHandler { [weak self, weak src] in
            guard let self, let src else { return }
            let mask = src.data
            if mask.contains(.write) {
                onChange()
            }
            if mask.contains(.rename) || mask.contains(.delete) {
                // File was replaced atomically. Read the new content, then
                // re-establish the watch on the new inode.
                onChange()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    self.watch(url, onChange: onChange)
                }
            }
        }

        src.setCancelHandler { close(fd) }
        src.resume()
        source = src
    }

    func stop() {
        source?.cancel()
        source = nil
    }

    deinit { stop() }
}
