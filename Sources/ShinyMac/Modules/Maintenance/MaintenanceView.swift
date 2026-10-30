import ShinyCore
import SwiftUI

struct MaintenanceView: View {
    @Bindable var model: MaintenanceModel

    private var theme: ModuleTheme { Module.maintenance.theme }

    var body: some View {
        ZStack {
            switch model.phase {
            case .idle:
                ModuleStartView(module: .maintenance, features: Module.maintenance.features, actionTitle: "View") {
                    model.showTasks()
                }
            case .list:
                taskList
            }
        }
        .transition(.opacity)
    }

    private var taskList: some View {
        VStack(spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("Maintenance").font(.display(24))
                Text(summary)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.6))
                    .contentTransition(.opacity)
                Spacer()
            }

            GlassCard(padding: 6) {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(model.tasks) { task in
                            TaskRow(model: model, task: task)
                        }
                    }
                }
                .scrollIndicators(.never)
            }

            HStack(spacing: 18) {
                if model.tasks.contains(where: { model.selected.contains($0.id) && $0.needsAdmin }) {
                    Label("Some tasks will ask for your password", systemImage: "lock.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.55))
                }
                OrbButton(
                    title: model.isRunning ? "…" : "Run", theme: theme, size: 80,
                    isEnabled: !model.selected.isEmpty && !model.isRunning
                ) { model.run() }
            }
        }
        .frame(maxWidth: 820)
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 18)
    }

    private var summary: String {
        if model.isRunning { return "Running tasks…" }
        if !model.statuses.isEmpty { return "\(model.completedCount) of \(model.statuses.count) tasks completed" }
        return "\(model.selected.count) tasks selected"
    }
}

private struct TaskRow: View {
    let model: MaintenanceModel
    let task: MaintenanceTask
    @State private var isHovering = false

    private var theme: ModuleTheme { Module.maintenance.theme }

    var body: some View {
        HStack(spacing: 14) {
            CheckCircle(state: model.selected.contains(task.id) ? .on : .off, tint: theme.accent)
            Image(systemName: task.symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(theme.iconGradient, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(task.title).font(.system(size: 14, weight: .semibold))
                    if task.needsAdmin {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.45))
                            .help("Asks for an administrator password")
                    }
                }
                Text(task.detail)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            status.frame(width: 120, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white.opacity(isHovering ? 0.06 : 0)))
        .contentShape(Rectangle())
        .onTapGesture { model.toggle(task) }
        .onHover { isHovering = $0 }
    }

    @ViewBuilder private var status: some View {
        switch model.statuses[task.id] {
        case .running?:
            ProgressView().controlSize(.small)
        case .waiting?:
            Text("Waiting").font(.system(size: 11.5)).foregroundStyle(.white.opacity(0.45))
        case .done?:
            Label("Done", systemImage: "checkmark.circle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.accent)
        case .failed(let message)?:
            Label("Failed", systemImage: "xmark.circle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(hex: 0xFF7A85))
                .help(message)
        case .skipped?:
            Text("Skipped").font(.system(size: 11.5)).foregroundStyle(.white.opacity(0.45))
        case nil:
            if let date = model.lastRun[task.id] {
                Text("Ran \(date.formatted(.relative(presentation: .named)))")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.white.opacity(0.45))
            } else {
                Text("Never run").font(.system(size: 11.5)).foregroundStyle(.white.opacity(0.35))
            }
        }
    }
}
