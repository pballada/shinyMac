import SwiftUI

/// Color story for a sidebar section: a dark aurora background, an accent and a bright icon gradient.
struct ModuleTheme: Equatable {
    var deep: Color
    var mid: Color
    var bright: Color
    var accent: Color
    var symbolGradient: [Color]

    var iconGradient: LinearGradient {
        LinearGradient(colors: symbolGradient, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// Colors for angular rings around buttons and progress indicators.
    var ring: [Color] { symbolGradient + [accent, symbolGradient[0]] }
}

extension SidebarSection {
    var theme: ModuleTheme {
        switch self {
        case .home:
            ModuleTheme(deep: Color(hex: 0x14082E), mid: Color(hex: 0x4E1A97), bright: Color(hex: 0xD2449A),
                        accent: Color(hex: 0xC77DFF), symbolGradient: [Color(hex: 0xFF8AD8), Color(hex: 0x8A5CFF)])
        case .cleanup:
            ModuleTheme(deep: Color(hex: 0x031F1A), mid: Color(hex: 0x0B6E5B), bright: Color(hex: 0x2FC98A),
                        accent: Color(hex: 0x4BE3A8), symbolGradient: [Color(hex: 0x9BFFCF), Color(hex: 0x16A980)])
        case .protection:
            ModuleTheme(deep: Color(hex: 0x220511), mid: Color(hex: 0x8F1342), bright: Color(hex: 0xF0607F),
                        accent: Color(hex: 0xFF7AA2), symbolGradient: [Color(hex: 0xFFB3C7), Color(hex: 0xE2336B)])
        case .performance:
            ModuleTheme(deep: Color(hex: 0x0E0B30), mid: Color(hex: 0x3F28B8), bright: Color(hex: 0x9D5CF5),
                        accent: Color(hex: 0xA78BFA), symbolGradient: [Color(hex: 0xD7C4FF), Color(hex: 0x6D4AFF)])
        case .applications:
            ModuleTheme(deep: Color(hex: 0x051632), mid: Color(hex: 0x124FB5), bright: Color(hex: 0x2FB2F0),
                        accent: Color(hex: 0x5CC8FF), symbolGradient: [Color(hex: 0xA6E4FF), Color(hex: 0x2A7BFF)])
        case .files:
            ModuleTheme(deep: Color(hex: 0x240E02), mid: Color(hex: 0xA8400D), bright: Color(hex: 0xF2A23A),
                        accent: Color(hex: 0xFFB547), symbolGradient: [Color(hex: 0xFFE29A), Color(hex: 0xFF7A1A)])
        }
    }
}

extension Module {
    var theme: ModuleTheme { section.theme }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

extension Font {
    /// Rounded display face used for titles and big numbers.
    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}
