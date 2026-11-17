import ShinyCore
import SwiftUI

/// Everything Smart Care is about to do, on one page laid out like Large & Old Files: junk categories, the Trash and
/// the speed-up tasks on the left, the files (or tasks) of the open one on the right. Run starts from here only.
struct SmartCareReviewView: View {
    @Bindable var model: SmartCareModel
    @State private var isConfirming = false

    private var theme: ModuleTheme { Module.smartCare.theme }

    var body: some View {
        VStack(spacing: 14) {
            ReviewHeader(title: "Review Smart Care", summary: summary) { model.finishReview() }

            HStack(spacing: 14) {
                GlassCard(padding: 8) {
                    ScrollView {
                        VStack(spacing: 2) {
                            ForEach(model.reviewEssentials) { essential in
                                ReviewSectionTitle(title: essential.title)
                                categories(for: essential)
                            }
                        }
                    }
                    .scrollIndicators(.never)
                }
                .frame(width: 300)

                GlassCard(padding: 0) {
                    VStack(spacing: 0) {
                        detail
                        Divider().overlay(.white.opacity(0.1))
                        ReviewFooter(
                            count: model.plannedItems.count, size: model.freeableBytes, reveal: model.plannedItems.map(\.url),
                            actionTitle: "Run Smart Care", symbol: "sparkles", tint: theme.accent,
                            isEnabled: !model.plannedEssentials.isEmpty
                        ) { isConfirming = true }
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 18)
        .confirmationDialog("Run Smart Care?", isPresented: $isConfirming, titleVisibility: .visible) {
            Button("Run Smart Care", role: .destructive) { model.run() }
        } message: {
            Text(confirmationMessage)
        }
    }

    private var summary: String {
        let tasks = model.enabled.contains(.speed) ? model.maintenance.selectedTasks.count : 0
        let space = "\(model.plannedItems.count) items · \(ByteFormat.string(model.freeableBytes))"
        return tasks > 0 ? "\(space) · \(tasks) task\(tasks == 1 ? "" : "s")" : space
    }

    private var confirmationMessage: String {
        var parts: [String] = []
        let plan = model.plannedEssentials
        if plan.contains(.junk) {
            parts.append("\(ByteFormat.string(model.junk.selectedSize)) of junk is deleted; apps rebuild it when needed.")
        }
        if plan.contains(.trash) { parts.append("Emptying the Trash can't be undone.") }
        if plan.contains(.speed) {
            let tasks = model.maintenance.selectedTasks
            parts.append("\(tasks.count) speed-up task\(tasks.count == 1 ? "" : "s") run\(tasks.count == 1 ? "s" : "")"
                + (tasks.contains(where: \.needsAdmin) ? " and may ask for your password." : "."))
        }
        return parts.joined(separator: " ")
    }

    @ViewBuilder
    private func categories(for essential: SmartCareModel.Essential) -> some View {
        switch essential {
        case .junk:
            ForEach(model.junk.groups) { group in
                ReviewCategoryRow(model: model.junk, group: group, isFocused: model.reviewFocus == .junk(groupID: group.id)) {
                    model.reviewFocus = .junk(groupID: group.id)
                }
            }
        case .trash:
            ForEach(model.trash.groups) { group in
                ReviewCategoryRow(model: model.trash, group: group, isFocused: model.reviewFocus == .trash(groupID: group.id)) {
                    model.reviewFocus = .trash(groupID: group.id)
                }
            }
        case .speed:
            let tasks = model.maintenance.tasks
            let selected = model.maintenance.selectedTasks.count
            ReviewCategoryLabel(
                title: "Speed-up tasks", detail: "Nothing is deleted", symbol: "bolt.fill", theme: Module.maintenance.theme,
                check: CheckState(selected: selected, total: tasks.count), sizeText: "\(selected) of \(tasks.count)",
                isFocused: model.reviewFocus == .speed,
                onToggle: {
                    let maintenance = model.maintenance
                    if maintenance.selected.count == tasks.count { maintenance.selected = [] } else { maintenance.selected = Set(tasks.map(\.id)) }
                },
                onFocus: { model.reviewFocus = .speed }
            )
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch model.reviewFocus {
        case .junk(let id)?:
            if let group = model.junk.groups.first(where: { $0.id == id }) {
                ReviewItemsPane(model: model.junk, group: group)
            } else {
                placeholder
            }
        case .trash(let id)?:
            if let group = model.trash.groups.first(where: { $0.id == id }) {
                ReviewItemsPane(model: model.trash, group: group)
            } else {
                placeholder
            }
        case .speed?:
            SpeedTasksPane(model: model.maintenance)
        case nil:
            placeholder
        }
    }

    private var placeholder: some View {
        Text("Pick a category to see what's in it")
            .foregroundStyle(.white.opacity(0.5))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// The maintenance tasks Smart Care runs after cleaning, each with its own checkbox.
private struct SpeedTasksPane: View {
    let model: MaintenanceModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Speed-up tasks").font(.system(size: 13, weight: .semibold))
                    Text("\(model.selectedTasks.count) of \(model.tasks.count) selected · run after cleaning")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.white.opacity(0.55))
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider().overlay(.white.opacity(0.1))

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(model.tasks) { task in
                        SpeedTaskRow(model: model, task: task)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}

private struct SpeedTaskRow: View {
    let model: MaintenanceModel
    let task: MaintenanceTask
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            CheckCircle(state: model.selected.contains(task.id) ? .on : .off, tint: Module.maintenance.theme.accent, size: 16)
            Image(systemName: task.symbol)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 24, height: 24)
                .background(Module.maintenance.theme.iconGradient, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 5) {
                    Text(task.title).font(.system(size: 13, weight: .medium)).lineLimit(1)
                    if task.needsAdmin {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.45))
                            .help("Asks for an administrator password")
                    }
                }
                Text(task.detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.45))
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
        .background(.white.opacity(isHovering ? 0.05 : 0))
        .contentShape(Rectangle())
        .onTapGesture { model.toggle(task) }
        .onHover { isHovering = $0 }
    }
}
