import SwiftUI

struct PhotoBrowserView: View {
    @ObservedObject var browserService: PhotoBrowserService
    let onConfirm: ([String]) -> Void
    let onCancel: () -> Void

    @State private var searchText = ""
    @State private var filterVideos = true
    @State private var filterPhotos = true

    private var filtered: [PhotoItem] {
        browserService.photos.filter { item in
            let matchesSearch = searchText.isEmpty ||
                item.filename.localizedCaseInsensitiveContains(searchText) ||
                item.folder.localizedCaseInsensitiveContains(searchText)
            let matchesType = item.isVideo ? filterVideos : filterPhotos
            return matchesSearch && matchesType
        }
    }

    private var selectedCount: Int {
        browserService.photos.filter { $0.isSelected }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: 12) {
                Text("Select Photos & Videos")
                    .font(.headline)
                Spacer()
                if browserService.isLoading {
                    ProgressView().controlSize(.small)
                    Text("Loading\u{2026} \(browserService.photos.count) found")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)

            Divider()

            // Filter bar
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search files or folders", text: $searchText)
                    .textFieldStyle(.plain)
                Toggle("Photos", isOn: $filterPhotos)
                    .toggleStyle(.checkbox)
                Toggle("Videos", isOn: $filterVideos)
                    .toggleStyle(.checkbox)
                Spacer()
                Button("All") {
                    for i in browserService.photos.indices {
                        if filtered.contains(where: { $0.id == browserService.photos[i].id }) {
                            browserService.photos[i].isSelected = true
                        }
                    }
                }
                .controlSize(.small)
                Button("None") {
                    for i in browserService.photos.indices {
                        if filtered.contains(where: { $0.id == browserService.photos[i].id }) {
                            browserService.photos[i].isSelected = false
                        }
                    }
                }
                .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider()

            if browserService.photos.isEmpty && !browserService.isLoading {
                VStack(spacing: 8) {
                    if let err = browserService.errorMessage {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text(err).foregroundColor(.secondary)
                    } else {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("No photos found").foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(Array(filtered.enumerated()), id: \.element.id) { _, item in
                        PhotoRowView(item: item) { isSelected in
                            if let idx = browserService.photos.firstIndex(where: { $0.id == item.id }) {
                                browserService.photos[idx].isSelected = isSelected
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }

            Divider()

            // Bottom bar
            HStack {
                Text("\(selectedCount) of \(browserService.photos.count) selected")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Cancel", action: onCancel)
                Button("Copy Selected (\(selectedCount))") {
                    onConfirm(browserService.selectedPaths)
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedCount == 0)
            }
            .padding(16)
        }
        .frame(minWidth: 600, minHeight: 500)
    }
}

struct PhotoRowView: View {
    let item: PhotoItem
    let onToggle: (Bool) -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item.isVideo ? "video" : "photo")
                .foregroundColor(item.isVideo ? .blue : .green)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.filename)
                    .font(.body)
                    .lineLimit(1)
                Text(item.folder)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text(item.sizeFormatted)
                .font(.caption)
                .foregroundColor(.secondary)
            Toggle("", isOn: Binding(
                get: { item.isSelected },
                set: { onToggle($0) }
            ))
            .labelsHidden()
            .toggleStyle(.checkbox)
        }
        .contentShape(Rectangle())
        .onTapGesture { onToggle(!item.isSelected) }
        .padding(.vertical, 2)
    }
}
