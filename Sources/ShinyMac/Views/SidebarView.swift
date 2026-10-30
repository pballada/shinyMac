import ShinyCore
import SwiftUI

struct SidebarView: View {
    @Environment(AppState.self) private var state
    @Namespace private var selectionNamespace

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            brand
                .padding(.top, 38)
                .padding(.horizontal, 18)
                .padding(.bottom, 4)

            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(SidebarSection.allCases) { section in
                        if let title = section.title {
                            Text(title.uppercased())
                                .font(.system(size: 10.5, weight: .semibold))
                                .tracking(0.8)
                                .foregroundStyle(.white.opacity(0.42))
                                .padding(.top, 10)
                                .padding(.bottom, 2)
                                .padding(.horizontal, 10)
                        }
                        ForEach(section.modules) { module in
                            SidebarRow(
                                module: module,
                                badge: state.badge(for: module),
                                isSelected: state.selection == module,
                                namespace: selectionNamespace
                            ) {
                                withAnimation(.spring(duration: 0.35)) { state.selection = module }
                            }
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
            }
            .scrollIndicators(.never)

            DiskUsageFooter()
                .padding(14)
        }
        .frame(width: 240)
        .background(.black.opacity(0.16), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shinyGlass(in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .padding(8)
    }

    private var brand: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(SidebarSection.home.theme.iconGradient)
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .bold))
            }
            .frame(width: 28, height: 28)
            Text("ShinyMac").font(.display(18))
        }
    }
}

private struct SidebarRow: View {
    let module: Module
    let badge: String?
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ModuleIcon(module: module, size: 24)
                Text(module.title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(.white.opacity(isSelected ? 1 : 0.85))
                    .lineLimit(1)
                Spacer(minLength: 4)
                if let badge {
                    Text(badge)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.7))
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4.5)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.white.opacity(0.16))
                        .matchedGeometryEffect(id: "selection", in: namespace)
                } else if isHovering {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.white.opacity(0.06))
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovering)
        .animation(.smooth, value: badge)
    }
}

/// Startup disk usage meter pinned to the bottom of the sidebar.
private struct DiskUsageFooter: View {
    @State private var volume = VolumeInfo.current()

    var body: some View {
        if let volume {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) {
                    Image(systemName: "internaldrive.fill")
                        .foregroundStyle(.white.opacity(0.7))
                    Text(volume.name).font(.system(size: 12, weight: .semibold))
                }
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.12))
                        Capsule()
                            .fill(LinearGradient(colors: [Color(hex: 0x5CC8FF), Color(hex: 0xC77DFF), Color(hex: 0xFF7AA2)],
                                                 startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(6, proxy.size.width * volume.usedFraction))
                    }
                }
                .frame(height: 6)
                Text("\(ByteFormat.string(volume.available)) available of \(ByteFormat.string(volume.total))")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.55))
            }
            .padding(12)
            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .task {
                // Refresh periodically so the meter reflects cleanups.
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(5))
                    self.volume = VolumeInfo.current()
                }
            }
        }
    }
}
