import ShinyCore
import SwiftUI

/// Routes a `CleanupModel` to the screen for its current phase.
struct CleanupModuleView: View {
    @Bindable var model: CleanupModel

    var body: some View {
        ZStack {
            switch model.phase {
            case .idle:
                ModuleStartView(module: model.module, features: model.module.features) { model.scan() }
            case .scanning:
                ModuleBusyView(
                    module: model.module, title: "Scanning…", detail: model.progress.detail,
                    foundBytes: model.progress.bytesFound, onStop: model.stop
                )
            case .results where model.isReviewing:
                CleanupReviewView(model: model)
            case .results:
                CleanupResultsView(model: model)
            case .cleaning:
                ModuleBusyView(
                    module: model.module, title: model.verb.progressive, detail: model.progress.detail,
                    progress: model.progress.fraction
                )
            case .done:
                CleanupDoneView(model: model)
            }
        }
        .transition(.opacity)
        .animation(.smooth, value: model.isReviewing)
    }
}

// MARK: - Results summary

struct CleanupResultsView: View {
    @Bindable var model: CleanupModel
    @State private var isConfirming = false

    private var theme: ModuleTheme { model.module.theme }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Scan Again", systemImage: "arrow.clockwise") { model.scan() }
                    .buttonStyle(.glassPill)
            }
            .padding(.horizontal, 28)
            .padding(.top, 10)

            Spacer(minLength: 8)
            HStack(spacing: 52) {
                HeroIllustration(symbol: model.module.symbol, theme: theme, size: 240)

                VStack(alignment: .leading, spacing: 10) {
                    Text(model.groups.isEmpty ? "All clean" : "Scan complete")
                        .font(.system(size: 12.5, weight: .bold))
                        .tracking(1.2)
                        .textCase(.uppercase)
                        .foregroundStyle(theme.iconGradient)
                    if model.groups.isEmpty {
                        Text("Nothing to clean")
                            .font(.display(40))
                        Text("Your Mac is already spotless here.")
                            .font(.system(size: 15))
                            .foregroundStyle(.white.opacity(0.7))
                    } else {
                        BigSize(bytes: model.selectedSize, size: 66)
                        Text("selected of \(ByteFormat.string(model.totalSize)) found")
                            .font(.system(size: 15))
                            .foregroundStyle(.white.opacity(0.7))
                        groupSummary.padding(.top, 10)
                        Button("Review Details…") { model.isReviewing = true }
                            .buttonStyle(.glassPill)
                            .padding(.top, 10)
                    }
                }
                .frame(width: 330, alignment: .leading)
            }
            Spacer(minLength: 8)

            OrbButton(title: model.cleanVerb, theme: theme, isEnabled: model.selectedSize > 0) {
                if model.confirmation == nil { model.clean() } else { isConfirming = true }
            }
            .padding(.bottom, 34)
        }
        .cleanupConfirmation(model: model, isPresented: $isConfirming)
    }

    private var groupSummary: some View {
        VStack(alignment: .leading, spacing: 9) {
            ForEach(model.groups.prefix(4)) { group in
                HStack(spacing: 10) {
                    Image(systemName: group.symbol)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(theme.iconGradient)
                        .frame(width: 20)
                    Text(group.title).font(.system(size: 13, weight: .medium))
                    Spacer()
                    Text(ByteFormat.string(group.size))
                        .font(.system(size: 12.5, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            if model.groups.count > 4 {
                Text("+ \(model.groups.count - 4) more categories")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
    }
}

// MARK: - Review (two-pane)

struct CleanupReviewView: View {
    @Bindable var model: CleanupModel
    @State private var isConfirming = false

    private var theme: ModuleTheme { model.module.theme }

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Button("Back", systemImage: "chevron.left") { model.finishReview() }
                    .buttonStyle(.glassPill)
                Spacer()
                Text(model.module.title).font(.display(20, weight: .semibold))
                Spacer()
                Text("\(ByteFormat.string(model.selectedSize)) selected")
                    .font(.system(size: 13, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(minWidth: 70, alignment: .trailing)
            }

            HStack(spacing: 14) {
                GlassCard(padding: 8) {
                    ScrollView {
                        VStack(spacing: 2) {
                            ForEach(model.groups) { group in
                                GroupRow(model: model, group: group, isFocused: model.focusedGroup?.id == group.id)
                            }
                        }
                    }
                    .scrollIndicators(.never)
                }
                .frame(width: 300)

                GlassCard(padding: 0) {
                    if let group = model.focusedGroup {
                        ItemsPane(model: model, group: group)
                    }
                }
            }

            OrbButton(title: model.cleanVerb, theme: theme, size: 80, isEnabled: model.selectedSize > 0) {
                if model.confirmation == nil { model.clean() } else { isConfirming = true }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 6)
        .padding(.bottom, 18)
        .cleanupConfirmation(model: model, isPresented: $isConfirming)
    }
}

private struct GroupRow: View {
    let model: CleanupModel
    let group: CleanupGroup
    let isFocused: Bool
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 10) {
            Button { model.toggle(group) } label: {
                CheckCircle(state: model.checkState(of: group), tint: model.module.theme.accent)
            }
            .buttonStyle(.plain)

            Image(systemName: group.symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(model.module.theme.iconGradient, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text(group.title).font(.system(size: 13, weight: .semibold))
                Text(group.detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            Text(ByteFormat.string(model.selectedSize(of: group)))
                .font(.system(size: 12, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.75))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.white.opacity(isFocused ? 0.14 : (isHovering ? 0.06 : 0)))
        )
        .contentShape(Rectangle())
        .onTapGesture { model.focusedGroupID = group.id }
        .onHover { isHovering = $0 }
    }
}

private struct ItemsPane: View {
    let model: CleanupModel
    let group: CleanupGroup

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.title).font(.display(18, weight: .semibold))
                    Text("\(group.items.count) items · \(ByteFormat.string(group.size))")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.55))
                }
                Spacer()
                Button(model.checkState(of: group) == .on ? "Deselect All" : "Select All") { model.toggle(group) }
                    .buttonStyle(.glassPill)
            }
            .padding(16)

            Divider().overlay(.white.opacity(0.1))

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(group.items) { item in
                        CleanupItemRow(model: model, item: item)
                    }
                }
                .padding(.vertical, 6)
            }
        }
    }
}

struct CleanupItemRow: View {
    let model: CleanupModel
    let item: CleanupItem
    @State private var isHovering = false

    private var title: String {
        item.name == item.url.lastPathComponent ? FileIcons.displayName(for: item.url) : item.name
    }

    var body: some View {
        HStack(spacing: 12) {
            Button { model.toggle(item) } label: {
                CheckCircle(state: model.selected.contains(item.url) ? .on : .off, tint: model.module.theme.accent, size: 16)
            }
            .buttonStyle(.plain)

            FileIconView(url: item.url, size: 24)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Text(Paths.abbreviated(item.url))
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.45))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 8)
            Text(ByteFormat.string(item.size))
                .font(.system(size: 12.5, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.75))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
        .background(.white.opacity(isHovering ? 0.05 : 0))
        .contentShape(Rectangle())
        .onTapGesture { model.toggle(item) }
        .onHover { isHovering = $0 }
        .contextMenu {
            Button("Reveal in Finder") { FileIcons.reveal([item.url]) }
        }
    }
}

// MARK: - Done

struct CleanupDoneView: View {
    let model: CleanupModel

    private var theme: ModuleTheme { model.module.theme }

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            HeroIllustration(symbol: "checkmark", theme: theme, size: 230)
            BigSize(bytes: model.report.removedBytes, size: 60)
            Text(model.lastMode == .trash ? "moved to the Trash" : "cleaned up")
                .font(.system(size: 16))
                .foregroundStyle(.white.opacity(0.7))

            if !model.report.failures.isEmpty {
                failureCard.frame(maxWidth: 460)
            }
            Spacer()
            Button("Done") { model.reset() }
                .buttonStyle(.glassPill(prominent: true, tint: theme.accent))
                .controlSize(.large)
                .padding(.bottom, 40)
        }
        .padding(.horizontal, 40)
    }

    private var failureCard: some View {
        GlassCard(padding: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Label("\(model.report.failures.count) items couldn't be removed", systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(hex: 0xFFD479))
                ForEach(model.report.failures.prefix(3)) { failure in
                    Text("\(Paths.abbreviated(failure.url)): \(failure.reason)")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                if !model.adminFailures.isEmpty {
                    Button("Remove \(model.adminFailures.count) with Administrator Password…", systemImage: "lock.fill") {
                        model.retryFailuresAsAdmin()
                    }
                    .buttonStyle(.glassPill)
                    .padding(.top, 4)
                }
            }
        }
    }
}

private extension View {
    func cleanupConfirmation(model: CleanupModel, isPresented: Binding<Bool>) -> some View {
        confirmationDialog(
            "\(model.cleanVerb) \(ByteFormat.string(model.selectedSize))?",
            isPresented: isPresented,
            titleVisibility: .visible
        ) {
            Button(model.cleanVerb, role: .destructive) { model.clean() }
        } message: {
            Text(model.confirmation ?? "")
        }
    }
}
