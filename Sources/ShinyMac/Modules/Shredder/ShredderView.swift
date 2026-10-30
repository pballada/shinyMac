import ShinyCore
import SwiftUI

struct ShredderView: View {
    @Bindable var model: ShredderModel
    @State private var isTargeted = false
    @State private var isConfirming = false

    private var theme: ModuleTheme { Module.shredder.theme }

    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Shredder").font(.display(30))
                    Text(Module.shredder.tagline)
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
                Button("Choose Files…", systemImage: "plus") { model.chooseFiles() }
                    .buttonStyle(.glassPill)
                if !model.items.isEmpty {
                    Button("Clear") { model.clear() }
                        .buttonStyle(.glassPill)
                }
            }

            if let report = model.report {
                outcome(report)
            }

            dropZone

            OrbButton(title: "Shred", theme: theme, size: 86, isEnabled: !model.items.isEmpty && !model.isShredding) {
                isConfirming = true
            }
            .padding(.bottom, 8)
        }
        .padding(.horizontal, 28)
        .padding(.top, 10)
        .padding(.bottom, 18)
        .confirmationDialog(
            "Delete \(model.items.count) item\(model.items.count == 1 ? "" : "s") permanently?",
            isPresented: $isConfirming, titleVisibility: .visible
        ) {
            Button("Shred \(ByteFormat.string(model.totalSize))", role: .destructive) { model.shred() }
        } message: {
            Text("They skip the Trash and can't be recovered.")
        }
    }

    private var dropZone: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(.white.opacity(isTargeted ? 0.10 : 0.03))
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(
                    isTargeted ? AnyShapeStyle(AngularGradient(colors: theme.ring, center: .center)) : AnyShapeStyle(.white.opacity(0.22)),
                    style: StrokeStyle(lineWidth: isTargeted ? 3 : 1.5, dash: model.items.isEmpty ? [9, 7] : [])
                )

            if model.items.isEmpty {
                VStack(spacing: 14) {
                    HeroIllustration(symbol: Module.shredder.symbol, theme: theme, size: 200, isBusy: isTargeted)
                    Text(isTargeted ? "Release to add" : "Drop files and folders here")
                        .font(.display(20, weight: .semibold))
                    Text("Nothing is deleted until you press Shred.")
                        .font(.system(size: 12.5))
                        .foregroundStyle(.white.opacity(0.55))
                }
            } else {
                VStack(spacing: 0) {
                    HStack {
                        Text("\(model.items.count) items · \(ByteFormat.string(model.totalSize))")
                            .font(.system(size: 12.5, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(.white.opacity(0.65))
                        if model.isMeasuring { ProgressView().controlSize(.mini) }
                        Spacer()
                        Text("Drop more to add").font(.system(size: 11.5)).foregroundStyle(.white.opacity(0.4))
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    Divider().overlay(.white.opacity(0.1))
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(model.items) { item in
                                ShredderRow(item: item) { model.remove(item) }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .animation(.smooth(duration: 0.2), value: isTargeted)
        .dropDestination(for: URL.self) { urls, _ in
            model.add(urls)
            return true
        } isTargeted: { isTargeted = $0 }
    }

    @ViewBuilder
    private func outcome(_ report: Cleaner.Report) -> some View {
        HStack(spacing: 10) {
            Image(systemName: report.failures.isEmpty ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(report.failures.isEmpty ? theme.accent : Color(hex: 0xFFD479))
            Text("Shredded \(report.removed.count) item\(report.removed.count == 1 ? "" : "s") (\(ByteFormat.string(report.removedBytes)))")
                .font(.system(size: 13, weight: .medium))
            if !report.failures.isEmpty {
                Text("· \(report.failures.count) couldn't be deleted")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.6))
            }
            Spacer()
            if !model.adminFailures.isEmpty {
                Button("Use Administrator Password…", systemImage: "lock.fill") { model.shredFailuresAsAdmin() }
                    .buttonStyle(.glassPill)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .shinyGlass(in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

private struct ShredderRow: View {
    let item: CleanupItem
    let onRemove: () -> Void
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            FileIconView(url: item.url, size: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.name).font(.system(size: 13, weight: .medium)).lineLimit(1)
                Text(Paths.abbreviated(item.url.deletingLastPathComponent()))
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.45))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 8)
            Text(ByteFormat.string(item.size))
                .font(.system(size: 12.5, weight: .semibold))
                .monospacedDigit()
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill").font(.system(size: 15))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(isHovering ? 0.7 : 0.3))
            .help("Remove from list")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 7)
        .background(.white.opacity(isHovering ? 0.05 : 0))
        .onHover { isHovering = $0 }
    }
}
