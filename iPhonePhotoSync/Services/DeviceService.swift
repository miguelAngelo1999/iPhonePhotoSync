import Foundation
import Combine

final class DeviceService: ObservableObject {
    @Published var device: DeviceInfo? = nil
    @Published var pairingState: PairingState = .unknown

    enum PairingState: Equatable {
        case unknown, paired, unpaired, denied
    }

    private var pollTimer: Timer?

    func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.probe()
        }
        probe()
    }

    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    func pair(completion: @escaping (Bool, String) -> Void) {
        run(tool: "idevicepair", args: ["pair"]) { output, exitCode in
            let success = exitCode == 0 || output.contains("SUCCESS")
            completion(success, output)
        }
    }

    private func probe() {
        run(tool: "ideviceinfo", args: ["-k", "DeviceName"]) { [weak self] output, exitCode in
            DispatchQueue.main.async {
                let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
                if exitCode == 0, !trimmed.isEmpty {
                    self?.pairingState = .paired
                    self?.fetchDeviceInfo()
                } else if output.contains("denied") {
                    self?.pairingState = .denied
                    self?.device = nil
                } else {
                    self?.pairingState = .unpaired
                    self?.device = nil
                }
            }
        }
    }

    private func fetchDeviceInfo() {
        let keys = ["DeviceName", "ProductVersion", "ProductType", "UniqueDeviceID"]
        var values: [String: String] = [:]
        let group = DispatchGroup()
        let lock = DispatchQueue(label: "com.iPhonePhotoSync.valuesLock")
        for key in keys {
            group.enter()
            run(tool: "ideviceinfo", args: ["-k", key]) { output, _ in
                let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
                lock.sync { values[key] = trimmed }
                group.leave()
            }
        }
        group.notify(queue: .main) { [weak self] in
            self?.device = DeviceInfo(
                udid: values["UniqueDeviceID"] ?? "",
                name: values["DeviceName"] ?? "iPhone",
                iOSVersion: values["ProductVersion"] ?? "",
                productType: values["ProductType"] ?? ""
            )
        }
    }

    func run(tool: String, args: [String], completion: @escaping (String, Int32) -> Void) {
        DispatchQueue.global(qos: .utility).async {
            let process = Process()
            let candidates = ["/opt/homebrew/bin/", "/usr/local/bin/", ""]
            process.executableURL = candidates
                .map { URL(fileURLWithPath: "\($0)\(tool)") }
                .first { FileManager.default.fileExists(atPath: $0.path) }
                ?? URL(fileURLWithPath: tool)
            process.arguments = args
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            do {
                try process.run()
                process.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                completion(output, process.terminationStatus)
            } catch {
                completion(error.localizedDescription, -1)
            }
        }
    }
}
