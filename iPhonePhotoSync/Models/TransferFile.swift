import Foundation

struct TransferFile: Identifiable {
    let id = UUID()
    let remotePath: String
    let filename: String
    var status: FileStatus

    enum FileStatus {
        case pending, copying, done, failed(String)
    }
}
