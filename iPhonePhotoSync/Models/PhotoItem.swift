import Foundation
import AppKit

struct PhotoItem: Identifiable, Hashable {
    let id: String       // remote path, unique
    let filename: String
    let folder: String   // e.g. "100APPLE"
    let size: Int64
    var isSelected: Bool = true
    var thumbnailData: Data? = nil

    var thumbnail: NSImage? {
        guard let data = thumbnailData else { return nil }
        return NSImage(data: data)
    }

    var isVideo: Bool {
        let ext = (filename as NSString).pathExtension.lowercased()
        return ["mov", "mp4", "m4v", "avi"].contains(ext)
    }

    var sizeFormatted: String {
        let mb = Double(size) / 1_048_576
        if mb >= 1 { return String(format: "%.1f MB", mb) }
        return String(format: "%.0f KB", Double(size) / 1024)
    }

    // Hashable ignores thumbnailData for performance
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: PhotoItem, rhs: PhotoItem) -> Bool { lhs.id == rhs.id }
}
