import ShinyCore
import SwiftUI

/// One block of a `ReviewSheet`: a category and the exact files it will remove.
struct ReviewSection: Identifiable {
    let id: String
    let title: String
    let symbol: String
    var note: String?
    var items: [CleanupItem] = []

    var size: Int64 { items.reduce(0) { $0 + $1.size } }
}

/// Last look before anything is removed: every file, grouped, with sizes. Nothing happens until the user confirms.
struct ReviewSheet: View {
    let title: String
    let message: String
    let sections: [ReviewSection]
    let confirmTitle: String
    let theme: ModuleTheme
    let onConfirm: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var expanded: Set<String> = []

    /// Rows drawn per section before collapsing into "and N more", to keep huge caches responsive.
    private let rowLimit = 300

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.display(22, weight: .semibold))
                Text(message)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(22)

            Divider().overlay(.white.opacity(0.1))

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(sections) { section in
                        sectionHeader(section)
                        if expanded.contains(section.id) {
                            ForEach(section.items.prefix(rowLimit)) { item in
                                ItemLine(item: item)
                            }
                            if section.items.count > rowLimit {
                                Text("and \(section.items.count - rowLimit) more")
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(.white.opacity(0.45))
                                    .padding(.leading, 62)
                                    .padding(.vertical, 6)
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            .frame(minHeight: 240)

            Divider().overlay(.white.opacity(0.1))

            HStack {
                Text("\(itemCount) items · \(ByteFormat.string(totalSize))")
                    .font(.system(size: 12.5, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.glassPill)
                    .keyboardShortcut(.cancelAction)
                Button(confirmTitle) {
                    dismiss()
                    onConfirm()
                }
                .buttonStyle(.glassPill(prominent: true, tint: theme.accent))
            }
            .padding(16)
        }
        .frame(width: 640, height: 560)
        .background(LinearGradient(colors: [theme.deep, Color(hex: 0x0B0B14)], startPoint: .top, endPoint: .bottom))
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
    }

    private var itemCount: Int { sections.reduce(0) { $0 + $1.items.count } }
    private var totalSize: Int64 { sections.reduce(0) { $0 + $1.size } }

    private func sectionHeader(_ section: ReviewSection) -> some View {
        let isOpen = expanded.contains(section.id)
        return Button {
            withAnimation(.snappy(duration: 0.2)) {
                if isOpen { expanded.remove(section.id) } else { expanded.insert(section.id) }
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .rotationEffect(.degrees(isOpen ? 90 : 0))
                    .foregroundStyle(.white.opacity(section.items.isEmpty ? 0 : 0.5))
                    .frame(width: 10)
                Image(systemName: section.symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 28, height: 28)
                    .background(theme.iconGradient, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text(section.title).font(.system(size: 13.5, weight: .semibold))
                    Text(section.note ?? "\(section.items.count) item\(section.items.count == 1 ? "" : "s")")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.white.opacity(0.55))
                }
                Spacer()
                if !section.items.isEmpty {
                    Text(ByteFormat.string(section.size))
                        .font(.system(size: 12.5, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(section.items.isEmpty)
    }
}

private struct ItemLine: View {
    let item: CleanupItem

    var body: some View {
        HStack(spacing: 10) {
            FileIconView(url: item.url, size: 20)
            VStack(alignment: .leading, spacing: 0) {
                Text(item.name).font(.system(size: 12, weight: .medium)).lineLimit(1)
                Text(Paths.abbreviated(item.url))
                    .font(.system(size: 10.5))
                    .foregroundStyle(.white.opacity(0.45))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 8)
            Text(ByteFormat.string(item.size))
                .font(.system(size: 11.5, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.65))
        }
        .padding(.leading, 62)
        .padding(.trailing, 18)
        .padding(.vertical, 4)
        .contextMenu { Button("Reveal in Finder") { FileIcons.reveal([item.url]) } }
    }
}
