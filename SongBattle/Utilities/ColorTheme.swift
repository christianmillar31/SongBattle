import SwiftUI

struct ColorTheme {
    static let primary = Color("SpotifyGreen")
    static let secondary = Color("DeepPurple")
    static let background = LinearGradient(
        gradient: Gradient(colors: [Color("GradientStart"), Color("GradientEnd")]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let text = Color.white
    static let accent = Color("NeonPink")
    
    // Card styles
    static let cardBackground = Color.black.opacity(0.4)
    static let cardBorder = Color.white.opacity(0.2)
    
    // Button styles
    static let buttonBackground = Color("SpotifyGreen")
    static let buttonText = Color.white
    
    // Loading animation colors
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