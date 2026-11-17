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
                    .overlay(alignment: .bottomTrailing) {
                        if let location = model.location {
                            ScanLocationMenu(location: location) { model.scan(at: $0) }
                                .padding(28)
                        }
                    }
            case .scanning:
                ModuleBusyView(
                    module: model.module, title: "Scanning\(model.location.map(ScanLocation.suffix) ?? "")…",
                    detail: model.progress.detail,
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

    private var theme: ModuleTheme { model.module.theme }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                if let location = model.location {
                    ScanLocationMenu(location: location) { model.scan(at: $0) }
                }
                Button("Scan Again", systemImage: "arrow.clockwise") { model.scan() }
                    .buttonStyle(.glassPill)
            }
            .padding(.horizontal, 28)
            .padding(.top, 10)

            Spacer(minLength: 8)
            HStack(spacing: 52) {
                HeroIllustration(symbol: model.module.symbol, theme: theme, size: 240)

                VStack(alignment: .leading, spacing: 10) {
                    Text(model.groups.isEmpty ? "All clean" : model.module.resultsEyebrow)
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
                        Text(model.module.resultsCaption(total: model.totalSize))
                            .font(.system(size: 15))
                            .foregroundStyle(.white.opacity(0.7))
                        groupSummary.padding(.top, 10)
                        Text("Nothing is removed until you review the list and confirm.")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.5))
                            .padding(.top, 8)
                    }
                }
                .frame(width: 330, alignment: .leading)
            }
            Spacer(minLength: 8)

            // Removal only ever starts from the review list, never straight from the summary.
            OrbButton(title: "Review", theme: theme, isEnabled: !model.groups.isEmpty) {
                model.isReviewing = true
            }
            .padding(.bottom, 34)
        }
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

/// Every file a scan found, laid out like Large & Old Files: categories on the left, the focused category's files on
/// the right, and the selection with the action at the foot of the file list.
struct CleanupReviewView: View {
    @Bindable var model: CleanupModel
    @State private var isConfirming = false

    private var theme: ModuleTheme { model.module.theme }

    var body: some View {
        VStack(spacing: 14) {
            ReviewHeader(title: model.module.title, summary: "\(model.groups.reduce(0) { $0 + $1.items.count }) items · \(ByteFormat.string(model.totalSize))") {
                model.finishReview()
            }

            HStack(spacing: 14) {
                GlassCard(padding: 8) {
                    ScrollView {
                        VStack(spacing: 2) {
                            ForEach(model.groups) { group in
                                ReviewCategoryRow(
                                    model: model, group: group, isFocused: model.focusedGroup?.id == group.id
                                ) { model.focusedGroupID = group.id }
                            }
                        }
                    }
                    .scrollIndicators(.never)
                }
                .frame(width: 300)

                GlassCard(padding: 0) {
                    VStack(spacing: 0) {
                        if let group = model.focusedGroup {
                            ReviewItemsPane(model: model, group: group)
                        } else {
                            Spacer()
                        }
                        Divider().overlay(.white.opacity(0.1))
                        ReviewFooter(
                            count: model.selectedItems.count, size: model.selectedSize, reveal: model.selectedItems.map(\.url),
                            actionTitle: model.cleanVerb, symbol: "trash", tint: theme.accent
                        ) { isConfirming = true }
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 18)
        .cleanupConfirmation(model: model, isPresented: $isConfirming)
    }
}

/// Top row of a review page: Back, the page title and what it holds.
struct ReviewHeader: View {
    let title: String
    let summary: String
    let onBack: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Button("Back", systemImage: "chevron.left", action: onBack)
                .buttonStyle(.glassPill)
                .keyboardShortcut(.cancelAction)
            Text(title).font(.display(24))
            Text(summary)
                .font(.system(size: 13))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.6))
            Spacer()
        }
    }
}

/// Foot of a file list: what's selected, Reveal, and the one action that acts on it.
struct ReviewFooter: View {
    let count: Int
    let size: Int64
    var reveal: [URL] = []
    let actionTitle: String
    var symbol = "trash"
    let tint: Color
    var isBusy = false
    /// Defaults to "something is selected".
    var isEnabled: Bool?
    let action: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text("\(count) selected").font(.system(size: 12)).foregroundStyle(.white.opacity(0.6))
                Text(ByteFormat.string(size)).font(.display(18, weight: .semibold)).monospacedDigit()
            }
            Spacer()
            Button("Reveal", systemImage: "folder") { FileIcons.reveal(reveal) }
                .buttonStyle(.glassPill)
                .disabled(reveal.isEmpty)
            Button(action: action) {
                Label(actionTitle, systemImage: symbol)
            }
            .buttonStyle(.glassPill(prominent: true, tint: tint))
            .disabled(isBusy || !(isEnabled ?? (count > 0)))
        }
        .padding(14)
    }
}

/// A category in the left column of a review page, with its own checkbox and the size selected in it.
struct ReviewCategoryRow: View {
    let model: CleanupModel
    let group: CleanupGroup
    let isFocused: Bool
    let onFocus: () -> Void

    var body: some View {
        ReviewCategoryLabel(
            title: group.title, detail: group.detail, symbol: group.symbol, theme: model.module.theme,
            check: model.checkState(of: group), sizeText: ByteFormat.string(model.selectedSize(of: group)), isFocused: isFocused,
            onToggle: { model.toggle(group) }, onFocus: onFocus
        )
    }
}

struct ReviewCategoryLabel: View {
    let title: String
    let detail: String
    let symbol: String
    let theme: ModuleTheme
    let check: CheckState
    let size: String
    let isFocused: Bool
    let onToggle: () -> Void
    let onFocus: () -> Void
    @State private var isHovering = false

    init(title: String, detail: String, symbol: String, theme: ModuleTheme, check: CheckState, sizeText: String,
         isFocused: Bool, onToggle: @escaping () -> Void, onFocus: @escaping () -> Void) {
        self.title = title
        self.detail = detail
        self.symbol = symbol
        self.theme = theme
        self.check = check
        self.size = sizeText
        self.isFocused = isFocused
        self.onToggle = onToggle
        self.onFocus = onFocus
    }

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onToggle) {
                CheckCircle(state: check, tint: theme.accent)
            }
            .buttonStyle(.plain)

            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(theme.iconGradient, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            Text(size)
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
        .onTapGesture(perform: onFocus)
        .onHover { isHovering = $0 }
    }
}

/// Small uppercase heading inside a review column.
struct ReviewSectionTitle: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 10.5, weight: .bold))
            .tracking(0.7)
            .foregroundStyle(.white.opacity(0.45))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .padding(.bottom, 2)
    }
}

/// The files of one category, each with its own checkbox, under a select-all header.
struct ReviewItemsPane: View {
    let model: CleanupModel
    let group: CleanupGroup

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button { model.toggle(group) } label: {
                    CheckCircle(state: model.checkState(of: group), tint: model.module.theme.accent, size: 16)
                }
                .buttonStyle(.plain)
                .help(model.checkState(of: group) == .on ? "Deselect All" : "Select All")
                VStack(alignment: .leading, spacing: 1) {
                    Text(group.title).font(.system(size: 13, weight: .semibold))
                    Text("\(group.items.count) items · \(ByteFormat.string(group.size))")
                        .font(.system(size: 11.5))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.55))
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider().overlay(.white.opacity(0.1))

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(group.items) { item in
                        CleanupItemRow(model: model, item: item, isKeeper: model.isKeeper(item, in: group))
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}

struct CleanupItemRow: View {
    let model: CleanupModel
    let item: CleanupItem
    var isKeeper = false
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
                Text(item.note ?? Paths.abbreviated(item.url))
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.45))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(Paths.abbreviated(item.url))
            }
            Spacer(minLength: 8)
            if isKeeper {
                Text("ORIGINAL")
                    .font(.system(size: 9.5, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .foregroundStyle(model.module.theme.accent)
                    .background(model.module.theme.accent.opacity(0.18), in: Capsule())
                    .help("This copy is kept even if every copy is selected")
            }
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
            Text(model.verb == .offload ? "freed up, still safe in the cloud" : model.lastMode == .trash ? "moved to the Trash" : "cleaned up")
                .font(.system(size: 16))
                .foregroundStyle(.white.opacity(0.7))

            if model.report.removedBytes > 0 {
                CoffeeNudge(tint: theme.accent).padding(.top, 6)
            }

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

extension View {
    func cleanupConfirmation(model: CleanupModel, isPresented: Binding<Bool>) -> some View {
        confirmationDialog(model.confirmationTitle, isPresented: isPresented, titleVisibility: .visible) {
            Button("\(model.cleanVerb) \(ByteFormat.string(model.selectedSize))", role: .destructive) { model.clean() }
        } message: {
            Text(model.confirmationMessage)
        }
    }
}
