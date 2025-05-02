import SwiftUI

struct ContentView: View {
    @EnvironmentObject var spotifyService: SpotifyService
    @StateObject private var gameService: GameService
    @State private var selectedTab = 0
    
    init() {
        // Initialize GameService with a temporary SpotifyService
        // The actual SpotifyService will be injected from the environment
        _gameService = StateObject(wrappedValue: GameService(spotifyService: SpotifyService()))
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            GameView()
                .environmentObject(gameService)
                .tabItem {
                    Label("Game", systemImage: "music.note")
                }
                .tag(0)
            
            TeamsView(gameService: gameService)
                .tabItem {
                    Label("Teams", systemImage: "person.3")
                }
                .tag(1)
            
            SettingsView(spotifyService: spotifyService)
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(2)
        }
        .onAppear {
            // Update GameService to use the environment's SpotifyService
            gameService.updateSpotifyService(spotifyService)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let spotify = SpotifyService()
        ContentView()
            .environmentObject(spotify)
    }
} 