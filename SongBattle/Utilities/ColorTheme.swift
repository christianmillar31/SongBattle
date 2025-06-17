import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

struct ColorTheme {
    static let backgroundColor = Color(hex: "F9FAFB")
    static let primaryText = Color(hex: "333333")
    static let accentColor = Color(hex: "1DB954")
    static let cardBackground = Color.white
    static let cardShadow = Color.black.opacity(0.05)
    static let buttonBackground = Color.white
    static let buttonBorder = Color(hex: "1DB954")
    static let buttonShadow = Color.black.opacity(0.1)
    static let primary = Color("SpotifyGreen")
    static let secondary = Color("DeepPurple")
    static let background = LinearGradient(
        gradient: Gradient(colors: [Color("GradientStart"), Color("GradientEnd")]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let text = Color.white
    static let accent = Color("NeonPink")
    static let loadingPrimary = Color("SpotifyGreen")
    static let loadingSecondary = Color("NeonPink")
    static let spotifyGreen = Color("SpotifyGreen")
    static let deepPurple = Color("DeepPurple")
    static let neonPink = Color("NeonPink")
    static let gradientStart = Color("GradientStart")
    static let gradientEnd = Color("GradientEnd")
}

extension Color {
    static let theme = ColorTheme.self
}

extension View {
    func glassBackground() -> some View {
        self.background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.5), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
}
