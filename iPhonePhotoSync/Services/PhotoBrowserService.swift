import Foundation
import Combine

final class PhotoBrowserService: ObservableObject {
    @Published var photos: [PhotoItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil

    private var process: Process?

    func load() {
        guard !isLoading else { return }
        isLoading = true
        photos = []
        errorMessage = nil

        let scriptPath = findScript()
        guard !scriptPath.isEmpty else {
            errorMessage = "list_photos.py not found"
            isLoading = false
            return
        }

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

            proc.arguments = [scriptPath]

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
                self?.isLoading = false
            }
        }
    }

    func cancel() {
        process?.interrupt()
        process = nil
    }

    var selectedPaths: [String] {
        photos.filter { $0.isSelected }.map { $0.id }
    }

    func selectAll() {
        for i in photos.indices { photos[i].isSelected = true }
    }

    func deselectAll() {
        for i in photos.indices { photos[i].isSelected = false }
    }

    private func parseLine(_ line: String) {
        guard !line.isEmpty else { return }
        if line.hasPrefix("DONE") { return }
        if line.hasPrefix("ERROR ") {
            DispatchQueue.main.async { [weak self] in
                self?.errorMessage = String(line.dropFirst(6))
            }
            return
        }
        guard let data = line.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let path = json["path"] as? String else { return }

        let size = json["size"] as? Int64 ?? (json["size"] as? Int).map { Int64($0) } ?? 0
        let components = path.split(separator: "/")
        let filename = String(components.last ?? Substring(path))
        let folder = components.count >= 2 ? String(components[components.count - 2]) : ""

        let item = PhotoItem(id: path, filename: filename, folder: folder, size: size)
        DispatchQueue.main.async { [weak self] in
            self?.photos.append(item)
        }
    }

    private func findScript() -> String {
        let candidates: [String] = [
            Bundle.main.path(forResource: "list_photos", ofType: "py"),
            (Bundle.main.resourcePath ?? "") + "/list_photos.py",
            (ProcessInfo.processInfo.environment["HOME"] ?? "") + "/fix-issues/iPhonePhotoSync/iPhonePhotoSync/Resources/list_photos.py",
        ].compactMap { $0 }
        return candidates.first {
            FileManager.default.fileExists(atPath: $0)
        } ?? ""
    }
}
