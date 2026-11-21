import Foundation
import Combine

// Thin bridge kept for future ViewModel-layer expansions.
// Core logic lives in TransferService and DeviceService.
final class TransferViewModel: ObservableObject {
    @Published var destinationPath: String

    init() {
        let pictures = FileManager.default
            .urls(for: .picturesDirectory, in: .userDomainMask)[0]
        destinationPath = pictures.appendingPathComponent("iPhonePhotos").path
    }
}
