import SwiftUI

// MARK: - Button Styles
struct PrimaryButtonStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.headline.bold())
            .foregroundColor(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.theme.spotifyGreen, Color.theme.deepPurple]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
            .shadow(color: Color.theme.spotifyGreen.opacity(0.3), radius: 10, x: 0, y: 5)
    }
}

struct SecondaryButtonStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.headline.bold())
            .foregroundColor(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        LinearGradient(
                            colors: [Color.theme.neonPink.opacity(0.5), Color.clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }
}

// MARK: - Card Styles
struct GlassCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(ColorTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 15))
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(ColorTheme.cardBorder, lineWidth: 1)
            )
    }
}

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .glassBackground()
            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
}

// MARK: - Text Styles
struct TitleStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.title.bold())
            .foregroundColor(ColorTheme.text)
            .shadow(radius: 2)
    }
}

// MARK: - Light Button Style
struct LightButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded))
            .foregroundColor(Color.theme.accentColor)
            .padding(.vertical, 14)
            .padding(.horizontal, 24)
            .background(Color.theme.buttonBackground)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.theme.accentColor, lineWidth: 1)
            )
            .shadow(color: Color.theme.buttonShadow, radius: 6, x: 0, y: 4)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - View Extensions
extension View {
    func primaryButtonStyle() -> some View {
        self.modifier(PrimaryButtonStyle())
    }
    
    func secondaryButtonStyle() -> some View {
        self.modifier(SecondaryButtonStyle())
    }
    
    func cardStyle() -> some View {
        self.modifier(CardStyle())
    }
    
    func glassCard() -> some View {
        modifier(GlassCardModifier())
    }
    
    func titleStyle() -> some View {
        modifier(TitleStyle())
    }
    
    func lightButtonStyle() -> some View {
        self.buttonStyle(LightButtonStyle())
    }
} 
