import SwiftUI

struct LoadingView: View {
    @State private var isAnimating = false
    @State private var pulsate = false
    
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color.theme.gradientStart, Color.theme.gradientEnd]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack {
                ZStack {
                    // Spinning ring
                    Circle()
                        .stroke(
                            AngularGradient(
                                gradient: Gradient(colors: [Color.theme.spotifyGreen, Color.theme.neonPink]),
                                center: .center
                            ),
                            lineWidth: 8
                        )
                        .frame(width: 80, height: 80)
                        .rotationEffect(Angle(degrees: isAnimating ? 360 : 0))
                    
                    // Music note
                    Image(systemName: "music.note")
                        .font(.system(size: 30))
                        .foregroundColor(Color.theme.spotifyGreen)
                        .scaleEffect(pulsate ? 1.2 : 0.8)
                }
                
                Text("Loading...")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding(.top, 20)
            }
            .glassBackground()
            .padding(40)
        }
        .onAppear {
            withAnimation(
                Animation.linear(duration: 2)
                    .repeatForever(autoreverses: false)
            ) {
                isAnimating = true
            }
            
            withAnimation(
                Animation.easeInOut(duration: 1)
                    .repeatForever(autoreverses: true)
            ) {
                pulsate = true
            }
        }
    }
}

#Preview {
    LoadingView()
} 