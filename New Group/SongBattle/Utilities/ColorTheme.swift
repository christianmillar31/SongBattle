import SwiftUI

struct ColorTheme {
    static let primary = Color("PrimaryColor")
    static let secondary = Color("SecondaryColor")
    static let accent = Color("AccentColor")
    static let background = Color("BackgroundColor")
    static let surface = Color("SurfaceColor")
    static let text = Color("TextColor")
    
    // Gradient presets
    static let primaryGradient = LinearGradient(
        colors: [Color("GradientStart"), Color("GradientEnd")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let surfaceGradient = LinearGradient(
        colors: [Color("SurfaceStart"), Color("SurfaceEnd")],
        startPoint: .top,
        endPoint: .bottom
    )
}

// Extension for custom modifiers
extension View {
    func primaryBackground() -> some View {
        self.background(ColorTheme.primaryGradient)
    }
    
    func surfaceBackground() -> some View {
        self.background(ColorTheme.surfaceGradient)
    }
    
    func glassBackground() -> some View {
        self.background(.ultraThinMaterial)
            .background(ColorTheme.surfaceGradient.opacity(0.3))
    }
} 