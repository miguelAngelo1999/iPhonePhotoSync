import SwiftUI

struct ContentView: View {
    @StateObject private var deviceService = DeviceService()
    @StateObject private var transferService = TransferService()
    @StateObject private var browserService = PhotoBrowserService()
    @State private var destination: URL = {
        let pictures = FileManager.default
            .urls(for: .picturesDirectory, in: .userDomainMask)[0]
        return pictures.appendingPathComponent("iPhonePhotos")
    }()
    @State private var showFilePicker = false
    @State private var showLog = false
    @State private var showBrowser = false

    var body: some View {
        VStack(spacing: 0) {
            DeviceHeaderView(
                device: deviceService.device,
                pairingState: deviceService.pairingState,
                onPair: handlePair
            )
            Divider()
            VStack(spacing: 24) {
                destinationRow
                transferSection
            }
            .padding(24)
            if showLog {
                Divider()
                LogView(entries: transferService.log)
                    .frame(height: 180)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onAppear { deviceService.startPolling() }
        .onDisappear { deviceService.stopPolling() }
        .animation(.easeInOut(duration: 0.2), value: showLog)
        .background(Color(NSColor.windowBackgroundColor))
        .sheet(isPresented: $showBrowser) {
            PhotoBrowserView(
                browserService: browserService,
                onConfirm: { selectedPaths in
                    showBrowser = false
                    startTransfer(selectedPaths: selectedPaths)
                },
                onCancel: {
                    showBrowser = false
                    browserService.cancel()
                }
            )
        }
    }

    private var destinationRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "folder")
                .foregroundColor(.secondary)
            Text(destination.path)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Choose\u{2026}") { showFilePicker = true }
                .controlSize(.small)
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                destination = url
            }
        }
    }

    private var transferSection: some View {
        VStack(spacing: 12) {
            if transferService.isRunning {
                VStack(spacing: 6) {
                    ProgressView(value: transferService.progress)
                        .progressViewStyle(.linear)
                    Text("\(transferService.totalCopied) / \(transferService.totalFiles) files")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Button("Cancel", role: .destructive) {
                    transferService.cancel()
                }
            } else if transferService.totalCopied > 0 {
                Label("\(transferService.totalCopied) files copied",
                      systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.headline)
                Button("Copy Again") { startTransfer() }
            } else {
                VStack(spacing: 10) {
                    Button(action: { startTransfer() }) {
                        Label("Copy All Photos & Videos",
                              systemImage: "square.and.arrow.down")
                            .font(.headline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(deviceService.pairingState != .paired)

                    Button(action: openBrowser) {
                        Label("Browse & Select",
                              systemImage: "checkmark.rectangle.stack")
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.bordered)
                    .disabled(deviceService.pairingState != .paired)
                }
            }

            if let err = transferService.errorMessage {
                Text(err)
                    .foregroundColor(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }

            if !transferService.log.isEmpty {
                Button(showLog ? "Hide Log" : "Show Log") {
                    withAnimation { showLog.toggle() }
                }
                .controlSize(.small)
                .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func startTransfer(selectedPaths: [String] = []) {
        try? FileManager.default.createDirectory(
            at: destination, withIntermediateDirectories: true)
        transferService.start(destination: destination,
                              deviceService: deviceService,
                              selectedPaths: selectedPaths)
        showLog = true
    }

    private func openBrowser() {
        browserService.photos = []
        browserService.errorMessage = nil
        showBrowser = true
        browserService.load()
    }

    private func handlePair() {
        deviceService.pair { success, msg in
            if !success {
                DispatchQueue.main.async {
                    transferService.errorMessage = msg
                }
            }
        }
    }
}
