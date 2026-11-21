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
        ZStack {
            // Full-window glass background
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                DeviceHeaderView(
                    device: deviceService.device,
                    pairingState: deviceService.pairingState,
                    onPair: handlePair
                )
                Divider().opacity(0.3)

                ScrollView {
                    VStack(spacing: 16) {
                        destinationCard
                        transferCard
                    }
                    .padding(20)
                }

                if showLog {
                    Divider().opacity(0.3)
                    LogView(entries: transferService.log)
                        .frame(height: 160)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .onAppear { deviceService.startPolling() }
        .onDisappear { deviceService.stopPolling() }
        .animation(.easeInOut(duration: 0.25), value: showLog)
        .sheet(isPresented: $showBrowser) {
            PhotoBrowserView(
                browserService: browserService,
                onConfirm: { paths in
                    showBrowser = false
                    startTransfer(selectedPaths: paths)
                },
                onCancel: {
                    showBrowser = false
                    browserService.cancel()
                }
            )
        }
    }

    // MARK: - Destination card
    private var destinationCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Save to", systemImage: "folder")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                Text(destination.path)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .font(.subheadline)
                Button("Choose\u{2026}") { showFilePicker = true }
                    .controlSize(.small)
                    .buttonStyle(.bordered)
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
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

    // MARK: - Transfer card
    private var transferCard: some View {
        VStack(spacing: 14) {
            if transferService.isRunning {
                runningState
            } else if transferService.totalCopied > 0 {
                doneState
            } else {
                idleState
            }

            if let err = transferService.errorMessage {
                Text(err)
                    .foregroundStyle(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }

            if !transferService.log.isEmpty {
                Button(showLog ? "Hide Log" : "Show Log") {
                    withAnimation { showLog.toggle() }
                }
                .controlSize(.small)
                .foregroundStyle(.secondary)
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private var runningState: some View {
        VStack(spacing: 10) {
            ProgressView(value: transferService.progress)
                .progressViewStyle(.linear)
                .tint(.accentColor)
            Text("\(transferService.totalCopied) / \(transferService.totalFiles) files")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Cancel", role: .destructive) { transferService.cancel() }
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
    }

    private var doneState: some View {
        VStack(spacing: 10) {
            Label("\(transferService.totalCopied) files copied",
                  systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.headline)
            Button("Copy Again") { startTransfer() }
                .buttonStyle(.bordered)
        }
    }

    private var idleState: some View {
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

    // MARK: - Actions
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
