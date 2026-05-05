import Darwin
import Foundation

actor ScriptRunner {
    private var processes: [String: Process] = [:]

    /// Launches `npm run <name>` in `dir`. Returns the PID, or -1 if already running.
    /// Calls `onOutput` (background thread) with raw stdout/stderr chunks.
    /// Calls `onExit` (background thread) with the termination status once done.
    func run(
        _ name: String,
        in dir: URL,
        onOutput: @escaping (String) -> Void,
        onExit: @escaping (Int32) -> Void
    ) throws -> Int32 {
        if let existing = processes[name], existing.isRunning { return -1 }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["npm", "run", name]
        process.currentDirectoryURL = dir
        process.environment = ProcessInfo.processInfo.environment
            .merging(["PATH": Shell.enrichedPath]) { _, new in new }

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        outPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let s = String(data: data, encoding: .utf8) else { return }
            onOutput(s)
        }
        errPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let s = String(data: data, encoding: .utf8) else { return }
            onOutput(s)
        }

        process.terminationHandler = { [weak self] p in
            outPipe.fileHandleForReading.readabilityHandler = nil
            errPipe.fileHandleForReading.readabilityHandler = nil
            let code = p.terminationStatus
            Task { [weak self] in
                await self?.remove(name)
                onExit(code)
            }
        }

        try process.run()
        processes[name] = process
        return process.processIdentifier
    }

    /// Sends SIGTERM immediately; escalates to SIGKILL after 3 s if the process is still alive.
    func terminate(_ name: String) async {
        guard let process = processes[name] else { return }
        let pid = process.processIdentifier
        process.terminate()
        try? await Task.sleep(nanoseconds: 3_000_000_000)
        if process.isRunning {
            Darwin.kill(pid, SIGKILL)
        }
    }

    private func remove(_ name: String) {
        processes.removeValue(forKey: name)
    }
}
