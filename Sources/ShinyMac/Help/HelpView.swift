import AppKit
import SwiftUI

/// The Help window: guides, one page per tool, settings, answers and support links.
struct HelpView: View {
    @State private var topic: HelpTopic = .welcome
    @State private var search = ""

    var body: some View {
        HStack(spacing: 0) {
            sidebar.frame(width: 250)
            Divider().overlay(.white.opacity(0.08))
            HelpPage(topic: topic) { topic = $0 }
                .id(topic)
                .transition(.opacity)
        }
        .background(LinearGradient(colors: [Color(hex: 0x14082E), Color(hex: 0x0B0B14)], startPoint: .topLeading, endPoint: .bottomTrailing))
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
        .frame(minWidth: 820, minHeight: 560)
        .animation(.smooth(duration: 0.2), value: topic)
    }

    private var sidebar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.white.opacity(0.5))
                TextField("Search help", text: $search).textFieldStyle(.plain)
            }
            .font(.system(size: 13))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .padding(.horizontal, 12)
            .padding(.top, 40)

            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    group(nil, HelpTopic.guides)
                    ForEach(SidebarSection.allCases) { section in
                        group(section.title ?? "Home", section.modules.map(HelpTopic.module))
                    }
                    group("More", HelpTopic.more)
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 12)
            }
            .scrollIndicators(.never)
        }
        .background(.black.opacity(0.18))
    }

    @ViewBuilder
    private func group(_ title: String?, _ topics: [HelpTopic]) -> some View {
        let matches = topics.filter(matches)
        if !matches.isEmpty {
            if let title {
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.horizontal, 10)
                    .padding(.top, 10)
                    .padding(.bottom, 2)
            }
            ForEach(matches) { item in
                Button { topic = item } label: {
                    HStack(spacing: 9) {
                        Image(systemName: item.symbol)
                            .font(.system(size: 11, weight: .semibold))
                            .frame(width: 22, height: 22)
                            .background(theme(for: item).iconGradient, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        Text(item.title).font(.system(size: 12.5, weight: topic == item ? .semibold : .medium)).lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(.white.opacity(topic == item ? 0.14 : 0)))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func matches(_ topic: HelpTopic) -> Bool {
        let query = search.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return true }
        return topic.title.localizedCaseInsensitiveContains(query)
            || topic.paragraphs.contains { $0.body.localizedCaseInsensitiveContains(query) }
    }
}

func theme(for topic: HelpTopic) -> ModuleTheme {
    if case .module(let module) = topic { return module.theme }
    return SidebarSection.home.theme
}

private struct HelpPage: View {
    let topic: HelpTopic
    let open: (HelpTopic) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(spacing: 16) {
                    Image(systemName: topic.symbol)
                        .font(.system(size: 24, weight: .semibold))
                        .frame(width: 54, height: 54)
                        .background(theme(for: topic).iconGradient, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                        .shadow(color: theme(for: topic).accent.opacity(0.5), radius: 10, y: 4)
                    Text(topic.title).font(.display(28))
                }
                .padding(.top, 18)

                ForEach(topic.paragraphs) { paragraph in
                    VStack(alignment: .leading, spacing: 6) {
                        if let title = paragraph.title {
                            Text(title).font(.system(size: 14, weight: .semibold))
                        }
                        Text(paragraph.body)
                            .font(.system(size: 13.5))
                            .foregroundStyle(.white.opacity(paragraph.title == nil ? 0.85 : 0.72))
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                    }
                }

                if case .module(let module) = topic, !module.features.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("What it covers").font(.system(size: 14, weight: .semibold))
                        ForEach(module.features) { FeatureRow(feature: $0, theme: module.theme) }
                    }
                }

                footer
            }
            .frame(maxWidth: 600, alignment: .leading)
            .padding(.horizontal, 36)
            .padding(.bottom, 36)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder private var footer: some View {
        switch topic {
        case .support:
            HStack(spacing: 10) {
                Button("Report an Issue", systemImage: "ladybug.fill") { NSWorkspace.shared.open(Support.issuesURL) }
                    .buttonStyle(.glassPill)
                Button("Source Code", systemImage: "chevron.left.forwardslash.chevron.right") { NSWorkspace.shared.open(Support.repoURL) }
                    .buttonStyle(.glassPill)
                Button("☕  Buy Me a Coffee") { NSWorkspace.shared.open(Support.coffeeURL) }
                    .buttonStyle(.glassPill(prominent: true, tint: Color(hex: 0xFFB547)))
            }
        case .welcome:
            Button("Read about safety", systemImage: "checkmark.shield") { open(.safety) }
                .buttonStyle(.glassPill)
        default:
            EmptyView()
        }
    }
}
