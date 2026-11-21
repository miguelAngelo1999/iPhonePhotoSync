import SwiftUI

struct LogView: View {
    let entries: [String]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(entries.enumerated()), id: \.offset) { idx, entry in
                        Text(entry)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                            .id(idx)
                    }
                }
                .padding(10)
            }
            .background(Color(NSColor.textBackgroundColor))
            .onChange(of: entries.count) {
                if entries.count > 0 {
                    withAnimation { proxy.scrollTo(entries.count - 1, anchor: .bottom) }
                }
            }
        }
    }
}
