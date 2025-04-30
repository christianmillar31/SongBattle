import SwiftUI

struct GameView: View {
    @EnvironmentObject var gameService: GameService
    @State private var showingScoreSheet = false
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Loading...")
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                isLoading = false
                            }
                        }
                } else if gameService.gameState == .notStarted {
                    startGameView
                } else if gameService.gameState == .inProgress {
                    gameInProgressView
                } else {
                    gameFinishedView
                }
            }
            .navigationTitle("Song Battle")
        }
    }
    
    private var startGameView: some View {
        VStack(spacing: 20) {
            Text("Welcome to Song Battle!")
                .font(.title)
                .padding()
            
            if gameService.teams.isEmpty {
                Text("Add teams to start playing")
                    .foregroundColor(.secondary)
            } else {
                Button(action: {
                    gameService.startGame()
                }) {
                    Text("Start Game")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding()
            }
        }
    }
    
    private var gameInProgressView: some View {
        VStack {
            if let round = gameService.currentRound {
                VStack(spacing: 20) {
                    if let song = round.song {
                        SongDisplayView(song: song, isPlaying: gameService.spotifyService.isPlaying)
                    } else {
                        ProgressView("Loading song...")
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        showingScoreSheet = true
                    }) {
                        Text("Submit Scores")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    .padding()
                }
            }
        }
        .sheet(isPresented: $showingScoreSheet) {
            ScoreSheetView(gameService: gameService)
        }
    }
    
    private var gameFinishedView: some View {
        VStack(spacing: 20) {
            Text("Game Over!")
                .font(.title)
                .padding()
            
            List(gameService.teams.sorted { $0.score > $1.score }) { team in
                HStack {
                    Text(team.name)
                    Spacer()
                    Text("\(team.score) points")
                        .foregroundColor(.blue)
                }
            }
            
            Button(action: {
                gameService.startGame()
            }) {
                Text("Play Again")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding()
        }
    }
}

struct SongDisplayView: View {
    let song: Track
    let isPlaying: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Now Playing")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text(song.name)
                .font(.title)
                .bold()
            
            Text(song.artist)
                .font(.title2)
            
            if isPlaying {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
            }
        }
        .padding()
    }
}

struct ScoreSheetView: View {
    let gameService: GameService
    @Environment(\.presentationMode) var presentationMode
    @State private var team1Title = false
    @State private var team1Artist = false
    @State private var team2Title = false
    @State private var team2Artist = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text(gameService.teams[0].name)) {
                    Toggle("Got Title", isOn: $team1Title)
                    Toggle("Got Artist", isOn: $team1Artist)
                }
                
                Section(header: Text(gameService.teams[1].name)) {
                    Toggle("Got Title", isOn: $team2Title)
                    Toggle("Got Artist", isOn: $team2Artist)
                }
                
                Button(action: {
                    gameService.submitScores(
                        team1Title: team1Title,
                        team1Artist: team1Artist,
                        team2Title: team2Title,
                        team2Artist: team2Artist
                    )
                    gameService.startNewRound()
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Next Song")
                        .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Submit Scores")
            .navigationBarItems(trailing: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

struct GameView_Previews: PreviewProvider {
    static var previews: some View {
        GameView()
            .environmentObject(GameService(spotifyService: SpotifyService()))
    }
} 