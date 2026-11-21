import SwiftUI
import AppKit

struct PhotoBrowserView: View {
    @ObservedObject var browserService: PhotoBrowserService
    let onConfirm: ([String]) -> Void
    let onCancel: () -> Void

    @State private var searchText = ""
    @State private var filterVideos = true
    @State private var filterPhotos = true
    private let columns = [GridItem(.adaptive(minimum: 130, maximum: 160), spacing: 12)]

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
        GlassEffectContainer {
            VStack(spacing: 0) {
                toolbar
                filterBar
                Divider().opacity(0.3)
                content
                Divider().opacity(0.3)
                bottomBar
            }
        }
        .frame(minWidth: 680, minHeight: 540)
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.title2).foregroundStyle(.primary)
            Text("Browse & Select").font(.headline)
            Spacer()
            if browserService.isLoading {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("\(browserService.photos.count) found")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 10)
    }

    private var filterBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary).font(.caption)
                TextField("Search", text: $searchText)
                    .textFieldStyle(.plain).font(.subheadline)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .glassEffect(in: .rect(cornerRadius: 8))
            .frame(maxWidth: 260)

            Toggle(isOn: $filterPhotos) {
                Label("Photos", systemImage: "photo").font(.caption)
            }.toggleStyle(.checkbox)

            Toggle(isOn: $filterVideos) {
                Label("Videos", systemImage: "video").font(.caption)
            }.toggleStyle(.checkbox)

            Spacer()

            Button("Select All") {
                for i in browserService.photos.indices {
                    if filtered.contains(where: { $0.id == browserService.photos[i].id }) {
                        browserService.photos[i].isSelected = true
                    }
                }
            }
            .controlSize(.small).buttonStyle(.bordered)

            Button("Deselect All") {
                for i in browserService.photos.indices {
                    if filtered.contains(where: { $0.id == browserService.photos[i].id }) {
                        browserService.photos[i].isSelected = false
                    }
                }
            }
            .controlSize(.small).buttonStyle(.bordered)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private var content: some View {
        if browserService.photos.isEmpty && !browserService.isLoading {
            emptyState
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(filtered) { item in
                        PhotoThumbnailCell(item: item) { isSelected in
                            if let idx = browserService.photos.firstIndex(where: { $0.id == item.id }) {
                                browserService.photos[idx].isSelected = isSelected
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            if let err = browserService.errorMessage {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 40)).foregroundStyle(.orange)
                Text(err).foregroundStyle(.secondary).multilineTextAlignment(.center)
            } else {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 40)).foregroundStyle(.secondary)
                Text("No photos found").foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var bottomBar: some View {
        HStack {
            Text("\(selectedCount) of \(browserService.photos.count) selected")
                .font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Button("Cancel", action: onCancel).keyboardShortcut(.cancelAction)
            Button("Copy \(selectedCount) Item\(selectedCount == 1 ? "" : "s")") {
                onConfirm(browserService.selectedPaths)
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedCount == 0)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 20).padding(.vertical, 14)
    }
}

// MARK: - Thumbnail cell
struct PhotoThumbnailCell: View {
    let item: PhotoItem
    let onToggle: (Bool) -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Card with glass effect
            VStack(spacing: 0) {
                // Thumbnail — aspect-fit so nothing is stretched
                ZStack {
                    Rectangle()
                        .fill(.quaternary)
                    if let img = item.thumbnail {
                        Image(nsImage: img)
                            .resizable()
                            .scaledToFit()  // fit, not fill — no stretching
                            .padding(4)
                    } else {
                        Image(systemName: item.isVideo ? "video.fill" : "photo.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(width: 140, height: 120)
                .clipped()

                // Label bar
                HStack(spacing: 4) {
                    if item.isVideo {
                        Image(systemName: "video.fill")
                            .font(.system(size: 9))
                    }
                    Text(item.filename)
                        .font(.system(size: 10, weight: .medium))
                        .lineLimit(1).truncationMode(.middle)
                    Spacer()
                    Text(item.sizeFormatted)
                        .font(.system(size: 9)).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 6).padding(.vertical, 5)
            }
            .frame(width: 140)
            .glassEffect(in: .rect(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(item.isSelected ? Color.accentColor : Color.clear, lineWidth: 2.5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .fill(item.isSelected ? Color.accentColor.opacity(0.12) : .clear)
            )

            // Checkmark badge
            ZStack {
                Circle()
                    .frame(width: 22, height: 22)
                    .glassEffect(in: .circle)
                if item.isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .padding(6)
        }
        .contentShape(Rectangle())
        .onTapGesture { onToggle(!item.isSelected) }
        .scaleEffect(item.isSelected ? 1.0 : 0.96)
        .animation(.spring(response: 0.2), value: item.isSelected)
    }
}
