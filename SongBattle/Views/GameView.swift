import SwiftUI

struct GameView: View {
    @EnvironmentObject var gameService: GameService
    @State private var showingScoreSheet = false
    @State private var showingEndGameAlert = false
    
    var body: some View {
        VStack {
            // Teams and scores
            ForEach(gameService.teams) { team in
                HStack {
                    Text(team.name)
                    Spacer()
                    Text("Score: \(team.score)")
                }
                .padding()
            }
            
            // Current song info
            if let currentTrack = gameService.spotifyService.currentTrack {
                VStack {
                    Text("Now Playing:")
                        .font(.headline)
                    Text(currentTrack.name)
                    Text(currentTrack.artist)
                }
                .padding()
            }
            
            // Game controls
            HStack {
                Button("Play Random Song") {
                    gameService.startNewRound()
                }
                .disabled(!gameService.spotifyService.isConnected)
                
                Button("Submit Scores") {
                    showingScoreSheet = true
                }
                .disabled(!gameService.spotifyService.isConnected || gameService.currentRound?.song == nil)
            }
            .padding()
            
            // End game button
            Button("End Game") {
                showingEndGameAlert = true
            }
            .padding()
            
            // Connection status
            if !gameService.spotifyService.isConnected {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.yellow)
                    Text("Connecting to Spotify...")
                }
                .padding()
            }
            
            // Error display
            if let error = gameService.spotifyService.error {
                Text(error.localizedDescription)
                    .foregroundColor(.red)
                    .padding()
            }
        }
        .sheet(isPresented: $showingScoreSheet) {
            ScoreSheetView()
        }
        .alert("End Game", isPresented: $showingEndGameAlert) {
            Button("Cancel", role: .cancel) { }
            Button("End Game", role: .destructive) {
                gameService.endGame()
            }
        } message: {
            Text("Are you sure you want to end the game?")
        }
    }
}

#Preview {
    GameView()
        .environmentObject(GameService(spotifyService: SpotifyService()))
} 