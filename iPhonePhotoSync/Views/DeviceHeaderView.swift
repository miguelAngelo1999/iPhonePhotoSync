import SwiftUI

struct DeviceHeaderView: View {
    let device: DeviceInfo?
    let pairingState: DeviceService.PairingState
    let onPair: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "iphone")
                .font(.system(size: 36))
                .foregroundColor(device != nil ? .primary : .secondary)

            VStack(alignment: .leading, spacing: 3) {
                if let d = device {
                    Text(d.name).font(.headline)
                    Text("iOS \(d.iOSVersion) · \(d.productType)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("No iPhone detected")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text(statusLabel)
                        .font(.caption)
                        .foregroundColor(statusColor)
                }
            }

            Spacer()

            if pairingState == .denied || pairingState == .unpaired {
                Button("Trust Computer", action: onPair)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            } else if pairingState == .paired {
                Label("Paired", systemImage: "lock.open.fill")
                    .font(.caption)
                    .foregroundColor(.green)
            } else {
                ProgressView().controlSize(.small)
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private var statusLabel: String {
        switch pairingState {
        case .denied:   return "Tap \u{2018}Trust\u{2019} on your iPhone"
        case .unpaired: return "Connect your iPhone via USB"
        case .paired:   return "Connected"
        case .unknown:  return "Detecting\u{2026}"
        }
    }

    private var statusColor: Color {
        switch pairingState {
        case .denied: return .orange
        default:      return .secondary
        }
    }
}
