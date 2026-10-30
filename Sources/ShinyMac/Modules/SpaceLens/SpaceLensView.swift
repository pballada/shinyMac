import ShinyCore
import SwiftUI

struct SpaceLensView: View {
    @Bindable var model: SpaceLensModel

    var body: some View {
        ZStack {
            switch model.phase {
            case .idle:
                ModuleStartView(module: .spaceLens, features: Module.spaceLens.features, actionTitle: "Map") { model.scan() }
                    .overlay(alignment: .bottomTrailing) {
                        Button("Choose Folder…", systemImage: "folder") { model.chooseFolder() }
                            .buttonStyle(.glassPill)
                            .padding(28)
                    }
            case .scanning:
                ModuleBusyView(
                    module: .spaceLens, title: "Measuring \(DiskTreeName.of(model.rootURL))…", detail: model.progress.detail,
                    foundBytes: model.progress.bytesFound, onStop: model.stop
                )
            case .ready:
                if let focus = model.focus { SpaceLensBrowser(model: model, focus: focus) }
            }
        }
        .transition(.opacity)
    }
}

private enum DiskTreeName {
    static func of(_ url: URL) -> String {
        url.standardizedFileURL == Paths.home.standardizedFileURL ? "your Home folder" : url.lastPathComponent
    }
}

private struct SpaceLensBrowser: View {
    let model: SpaceLensModel
    let focus: DiskNode
    @State private var isConfirming = false

    private var theme: ModuleTheme { Module.spaceLens.theme }

    var body: some View {
        let _ = model.revision
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                breadcrumbs
                Spacer()
                Button("Choose Folder…", systemImage: "folder") { model.chooseFolder() }
                    .buttonStyle(.glassPill)
                Button("Rescan", systemImage: "arrow.clockwise") { model.scan() }
                    .buttonStyle(.glassPill)
            }

            if let report = model.lastReport {
                ResultBanner(report: report, tint: theme.accent)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            HStack(spacing: 14) {
                SunburstChart(model: model, focus: focus)
                    .id(ObjectIdentifier(focus))
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
                    .frame(minWidth: 360)
                    .padding(8)

                childList.frame(width: 330)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 18)
        .confirmationDialog(
            "Move \(model.selection.count) items to the Trash?", isPresented: $isConfirming, titleVisibility: .visible
        ) {
            Button("Move to Trash", role: .destructive) { model.removeSelected() }
        } message: {
            Text("\(ByteFormat.string(model.selectedSize)) will be moved to the Trash.")
        }
    }

    private var breadcrumbs: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 4) {
                ForEach(Array(focus.ancestry.enumerated()), id: \.element.id) { index, node in
                    if index > 0 {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    Button(node.name) { model.zoom(into: node) }
                        .buttonStyle(.plain)
                        .font(.system(size: node === focus ? 17 : 13, weight: node === focus ? .bold : .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(node === focus ? 1 : 0.6))
                }
            }
        }
        .scrollIndicators(.never)
    }

    private var childList: some View {
        GlassCard(padding: 0) {
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(focus.name).font(.display(17, weight: .semibold)).lineLimit(1)
                        Text("\(ByteFormat.string(focus.size)) · \(focus.children.count) items")
                            .font(.system(size: 11.5))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    Spacer()
                }
                .padding(14)

                Divider().overlay(.white.opacity(0.1))

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(focus.children.enumerated()), id: \.element.id) { index, child in
                            ChildRow(model: model, node: child, parentSize: focus.size, color: rowColor(child, index: index))
                        }
                    }
                    .padding(.vertical, 4)
                }

                Divider().overlay(.white.opacity(0.1))

                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(model.selection.count) selected").font(.system(size: 12)).foregroundStyle(.white.opacity(0.6))
                        Text(ByteFormat.string(model.selectedSize)).font(.display(17, weight: .semibold)).monospacedDigit()
                    }
                    Spacer()
                    Button {
                        isConfirming = true
                    } label: {
                        Label(model.isRemoving ? "Removing…" : "Remove", systemImage: "trash")
                    }
                    .buttonStyle(.glassPill(prominent: true, tint: theme.accent))
                    .disabled(model.selection.isEmpty || model.isRemoving)
                }
                .padding(14)
            }
        }
    }

    private func rowColor(_ node: DiskNode, index: Int) -> Color {
        node.isAggregate ? Color(white: 0.45) : SunburstChart.palette[index % SunburstChart.palette.count]
    }
}

private struct ChildRow: View {
    let model: SpaceLensModel
    let node: DiskNode
    let parentSize: Int64
    let color: Color

    private var fraction: Double { parentSize > 0 ? Double(node.size) / Double(parentSize) : 0 }

    var body: some View {
        HStack(spacing: 10) {
            if node.isAggregate {
                Color.clear.frame(width: 16, height: 16)
            } else {
                Button { model.toggleSelection(node) } label: {
                    CheckCircle(state: model.isSelected(node) ? .on : .off, tint: Module.spaceLens.theme.accent, size: 16)
                }
                .buttonStyle(.plain)
            }
            RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 4, height: 28)
            if node.isAggregate {
                Image(systemName: "ellipsis.circle.fill").font(.system(size: 18)).foregroundStyle(.white.opacity(0.5)).frame(width: 24)
            } else {
                FileIconView(url: node.url, size: 24)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(node.name).font(.system(size: 12.5, weight: .medium)).lineLimit(1)
                GeometryReader { proxy in
                    Capsule().fill(.white.opacity(0.1))
                        .overlay(alignment: .leading) {
                            Capsule().fill(color.gradient).frame(width: max(3, proxy.size.width * fraction))
                        }
                }
                .frame(height: 4)
            }
            Text(ByteFormat.string(node.size))
                .font(.system(size: 12, weight: .semibold))
                .monospacedDigit()
                .frame(width: 70, alignment: .trailing)
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(node.canDrillDown ? 0.5 : 0))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(.white.opacity(model.hovered === node ? 0.08 : 0))
        .contentShape(Rectangle())
        .onTapGesture { if node.canDrillDown { model.zoom(into: node) } else { model.toggleSelection(node) } }
        .onHover { hovering in model.hovered = hovering ? node : (model.hovered === node ? nil : model.hovered) }
        .contextMenu {
            if !node.isAggregate { Button("Reveal in Finder") { FileIcons.reveal([node.url]) } }
        }
    }
}
