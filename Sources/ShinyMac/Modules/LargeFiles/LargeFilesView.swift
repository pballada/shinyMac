import ShinyCore
import SwiftUI

struct LargeFilesView: View {
    @Bindable var model: LargeFilesModel

    var body: some View {
        ZStack {
            switch model.phase {
            case .idle:
                ModuleStartView(module: .largeFiles, features: Module.largeFiles.features) { model.scan() }
            case .scanning:
                ModuleBusyView(
                    module: .largeFiles, title: "Looking for large files…", detail: model.progress.detail,
                    foundBytes: model.progress.bytesFound, onStop: model.stop
                )
            case .ready:
                LargeFilesBrowser(model: model)
            }
        }
        .transition(.opacity)
    }
}

private struct LargeFilesBrowser: View {
    @Bindable var model: LargeFilesModel
    @State private var isConfirming = false

    private var theme: ModuleTheme { Module.largeFiles.theme }

    var body: some View {
        VStack(spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Large & Old Files").font(.display(24))
                Text("\(model.files.count) files · \(ByteFormat.string(model.totalSize))")
                    .font(.system(size: 13))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
                Button("Scan Again", systemImage: "arrow.clockwise") { model.scan() }
                    .buttonStyle(.glassPill)
            }

            if let report = model.lastReport {
                ResultBanner(report: report, tint: theme.accent)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            HStack(spacing: 14) {
                filters.frame(width: 230)
                fileList
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 18)
        .confirmationDialog(
            "Move \(model.selectedFiles.count) files to the Trash?", isPresented: $isConfirming, titleVisibility: .visible
        ) {
            Button("Move to Trash", role: .destructive) { model.removeSelected() }
        } message: {
            Text("\(ByteFormat.string(model.selectedSize)) will be moved to the Trash. You can still restore them from there.")
        }
    }

    private var filters: some View {
        GlassCard(padding: 10) {
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    sectionTitle("Kind")
                    KindRow(title: "All Files", symbol: "square.grid.2x2.fill", stats: model.stats(for: nil), isOn: model.kind == nil) {
                        model.kind = nil
                    }
                    ForEach(FileKind.allCases) { kind in
                        let stats = model.stats(for: kind)
                        if stats.count > 0 {
                            KindRow(title: kind.rawValue, symbol: kind.symbol, stats: stats, isOn: model.kind == kind) {
                                model.kind = kind
                            }
                        }
                    }

                    sectionTitle("Last used").padding(.top, 10)
                    Picker("Last used", selection: $model.age) {
                        ForEach(LargeFilesModel.Age.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .labelsHidden()
                    .padding(.horizontal, 6)

                    sectionTitle("Size").padding(.top, 10)
                    Picker("Size", selection: $model.sizeFloor) {
                        ForEach(LargeFilesModel.SizeFloor.allCases) { Text($0.title).tag($0) }
                    }
                    .labelsHidden()
                    .padding(.horizontal, 6)
                }
            }
            .scrollIndicators(.never)
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 10.5, weight: .bold))
            .tracking(0.7)
            .foregroundStyle(.white.opacity(0.45))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
    }

    private var fileList: some View {
        GlassCard(padding: 0) {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    let visible = model.visibleFiles
                    Button { model.toggleAllVisible() } label: {
                        CheckCircle(
                            state: CheckState(selected: visible.count { model.selection.contains($0.url) }, total: max(visible.count, 1)),
                            tint: theme.accent, size: 16
                        )
                    }
                    .buttonStyle(.plain)
                    Text("\(visible.count) files")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                    Spacer()
                    Picker("Sort", selection: $model.sort) {
                        ForEach(LargeFilesModel.Sort.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                Divider().overlay(.white.opacity(0.1))

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(model.visibleFiles) { file in
                            LargeFileRow(model: model, file: file)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .overlay {
                    if model.visibleFiles.isEmpty {
                        VStack(spacing: 6) {
                            Image(systemName: "sparkles").font(.system(size: 28))
                            Text("Nothing matches these filters").foregroundStyle(.white.opacity(0.6))
                        }
                    }
                }

                Divider().overlay(.white.opacity(0.1))

                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(model.selectedFiles.count) selected").font(.system(size: 12)).foregroundStyle(.white.opacity(0.6))
                        Text(ByteFormat.string(model.selectedSize)).font(.display(18, weight: .semibold)).monospacedDigit()
                    }
                    Spacer()
                    Button("Reveal", systemImage: "folder") { FileIcons.reveal(model.selectedFiles.map(\.url)) }
                        .buttonStyle(.glassPill)
                        .disabled(model.selectedFiles.isEmpty)
                    Button {
                        isConfirming = true
                    } label: {
                        Label(model.isRemoving ? "Removing…" : "Remove", systemImage: "trash")
                    }
                    .buttonStyle(.glassPill(prominent: true, tint: theme.accent))
                    .disabled(model.selectedFiles.isEmpty || model.isRemoving)
                }
                .padding(14)
            }
        }
    }
}

private struct KindRow: View {
    let title: String
    let symbol: String
    let stats: (count: Int, size: Int64)
    let isOn: Bool
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 24, height: 24)
                    .background(Module.largeFiles.theme.iconGradient.opacity(isOn ? 1 : 0.55), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                VStack(alignment: .leading, spacing: 0) {
                    Text(title).font(.system(size: 12.5, weight: .semibold))
                    Text("\(stats.count) · \(ByteFormat.string(stats.size))")
                        .font(.system(size: 10.5))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.5))
                }
                Spacer()
            }
            .padding(6)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.white.opacity(isOn ? 0.15 : (isHovering ? 0.06 : 0))))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}

private struct LargeFileRow: View {
    let model: LargeFilesModel
    let file: LargeFile
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            CheckCircle(state: model.selection.contains(file.url) ? .on : .off, tint: Module.largeFiles.theme.accent, size: 16)
            FileIconView(url: file.url, size: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(file.url.lastPathComponent).font(.system(size: 13, weight: .medium)).lineLimit(1)
                Text(Paths.abbreviated(file.url.deletingLastPathComponent()))
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.45))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 8)
            if let lastUsed = file.lastUsed {
                Text(lastUsed.formatted(.relative(presentation: .named)))
                    .font(.system(size: 11.5))
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(width: 110, alignment: .trailing)
            }
            Text(ByteFormat.string(file.size))
                .font(.system(size: 12.5, weight: .semibold))
                .monospacedDigit()
                .frame(width: 76, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(.white.opacity(isHovering ? 0.05 : 0))
        .contentShape(Rectangle())
        .onTapGesture { model.toggle(file) }
        .onHover { isHovering = $0 }
        .contextMenu {
            Button("Open") { NSWorkspace.shared.open(file.url) }
            Button("Reveal in Finder") { FileIcons.reveal([file.url]) }
        }
    }
}

/// One-line summary after a removal, used by browser-style modules.
struct ResultBanner: View {
    let report: Cleaner.Report
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: report.failures.isEmpty ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(report.failures.isEmpty ? tint : Color(hex: 0xFFD479))
            Text("Moved \(report.removed.count) items (\(ByteFormat.string(report.removedBytes))) to the Trash")
                .font(.system(size: 13, weight: .medium))
            if !report.failures.isEmpty {
                Text("· \(report.failures.count) couldn't be moved")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.6))
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .shinyGlass(in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
