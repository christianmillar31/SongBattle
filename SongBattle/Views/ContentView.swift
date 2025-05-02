import SwiftUI

struct ContentView: View {
    @StateObject private var spotifyService = SpotifyService.shared
    @StateObject private var gameService: GameService
    @State private var isLoading = true
    @State private var showingSettings = false
    
    init() {
        _gameService = StateObject(wrappedValue: GameService(spotifyService: SpotifyService.shared))
    }
    
    var body: some View {
        NavigationView {
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
                        Text("SongSmash")
                            .font(.largeTitle.bold())
                            .foregroundColor(.white)
                        
                        TeamsView(gameService: gameService)
                            .cardStyle()
                            .environmentObject(gameService)
                        
                        NavigationLink(destination: GameView().environmentObject(gameService)) {
                            Text("Start Game")
                                .font(.title3.weight(.semibold))
                        }
                        .primaryButtonStyle()
                        .disabled(!spotifyService.isConnected || gameService.teams.count < 2)
                    }
                    .padding()
                    .toolbar {
                        Button(action: { showingSettings = true }) {
                            Image(systemName: "gear")
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(spotifyService: spotifyService)
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