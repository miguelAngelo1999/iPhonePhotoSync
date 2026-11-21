import Foundation
import Combine

final class TransferService: ObservableObject {
    @Published var isRunning = false
    @Published var log: [String] = []
    @Published var totalCopied = 0
    @Published var totalFiles = 0
    @Published var errorMessage: String? = nil

    private var process: Process?

    var progress: Double {
        guard totalFiles > 0 else { return 0 }
        return Double(totalCopied) / Double(totalFiles)
    }

    func start(destination: URL, deviceService: DeviceService, selectedPaths: [String] = []) {
        guard !isRunning else { return }
        isRunning = true
        log = []
        totalCopied = 0
        totalFiles = 0
        errorMessage = nil

        let scriptPath = findScript()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let proc = Process()
            self.process = proc

            let pythonCandidates = [
                "/opt/homebrew/bin/python3",
                "/usr/bin/python3",
                "/usr/local/bin/python3"
            ]
            proc.executableURL = pythonCandidates
                .map { URL(fileURLWithPath: $0) }
                .first { FileManager.default.fileExists(atPath: $0.path) }
                ?? URL(fileURLWithPath: "/usr/bin/python3")

            // Pass selected paths as extra arguments; transfer.py copies only those when present
            proc.arguments = [scriptPath, destination.path] + selectedPaths

            var env = ProcessInfo.processInfo.environment
            env["PYTHONUNBUFFERED"] = "1"
            proc.environment = env

            let pipe = Pipe()
            proc.standardOutput = pipe
            proc.standardError = pipe

            pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                guard !data.isEmpty,
                      let text = String(data: data, encoding: .utf8) else { return }
                for line in text.components(separatedBy: .newlines) {
                    self?.parseLine(line.trimmingCharacters(in: .whitespaces))
                }
            }

            do {
                try proc.run()
                proc.waitUntilExit()
            } catch {
                DispatchQueue.main.async { [weak self] in
                    self?.errorMessage = error.localizedDescription
                }
            }

            pipe.fileHandleForReading.readabilityHandler = nil
            DispatchQueue.main.async { [weak self] in
                self?.isRunning = false
            }
        }
    }

    func cancel() {
        process?.interrupt()
        process = nil
    }

    private func parseLine(_ line: String) {
        guard !line.isEmpty else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if line.hasPrefix("COPYING ") {
                let name = URL(fileURLWithPath: String(line.dropFirst(8))).lastPathComponent
                self.log.append("\u{1F4F8} " + name)
            } else if line.hasPrefix("PROGRESS ") {
                let parts = line.split(separator: " ")
                if parts.count >= 3 {
                    self.totalCopied = Int(parts[1]) ?? self.totalCopied
                    self.totalFiles  = Int(parts[2]) ?? self.totalFiles
                }
            } else if line.hasPrefix("ERROR ") {
                self.log.append("\u{26A0}\u{FE0F} " + String(line.dropFirst(6)))
            } else {
                self.log.append(line)
            }
        }
    }

    private func findScript() -> String {
        let candidates: [String] = [
            Bundle.main.path(forResource: "transfer", ofType: "py"),
            (Bundle.main.resourcePath ?? "") + "/transfer.py",
            (ProcessInfo.processInfo.environment["HOME"] ?? "") + "/fix-issues/transfer.py",
        ].compactMap { $0 }
        return candidates.first {
            FileManager.default.fileExists(atPath: $0)
        } ?? ""
    }
}
