import SwiftUI

struct ContentView: View {
    @StateObject private var spotifyService = SpotifyService()
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [Color.theme.gradientStart, Color.theme.gradientEnd]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            if isLoading {
                LoadingView()
            } else {
                VStack(spacing: 20) {
                    Text("SongBattle")
                        .font(.largeTitle.bold())
                        .foregroundColor(.white)
                    
                    TeamsView()
                        .cardStyle()
                    
                    NavigationLink(destination: GameView()) {
                        Text("Start Game")
                            .font(.title3.weight(.semibold))
                    }
                    .primaryButtonStyle()
                }
                .padding()
            }
        }
        .onAppear {
            // Simulate loading time and initialize services
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    isLoading = false
                }
            }
        }
    }
}

#Preview {
    ContentView()
} 