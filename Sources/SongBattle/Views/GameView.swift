import SwiftUI

struct GameView: View {
    @StateObject private var spotifyService = SpotifyService()
    @StateObject private var gameService: GameService
    @State private var showingAnswerSheet = false
    @State private var selectedTeam: Team?
    
    init() {
        let spotifyService = SpotifyService()
        _gameService = StateObject(wrappedValue: GameService(spotifyService: spotifyService))
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if gameService.gameState == .notStarted {
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
                    Text("Current Team: \(round.team.name)")
                        .font(.headline)
                    
                    if let track = spotifyService.currentTrack {
                        SongDisplayView(song: track, isPlaying: spotifyService.isPlaying)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 20) {
                        Button(action: {
                            spotifyService.skipPrevious()
                        }) {
                            Image(systemName: "backward.fill")
                                .font(.title)
                        }
                        
                        Button(action: {
                            if spotifyService.isPlaying {
                                spotifyService.pause()
                            } else {
                                spotifyService.resume()
                            }
                        }) {
                            Image(systemName: spotifyService.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 64))
                        }
                        
                        Button(action: {
                            spotifyService.skipNext()
                        }) {
                            Image(systemName: "forward.fill")
                                .font(.title)
                        }
                    }
                    .padding()
                    
                    Button(action: {
                        selectedTeam = round.team
                        showingAnswerSheet = true
                    }) {
                        Text("Submit Answer")
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
        .sheet(isPresented: $showingAnswerSheet) {
            if let team = selectedTeam {
                AnswerSheetView(team: team, gameService: gameService)
            }
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
    let song: Song
    let isPlaying: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Now Playing")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text(song.title)
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

struct Song: Identifiable {
    let id = UUID()
    let title: String
    let artist: String
    let spotifyURI: String
}

struct AnswerSheetView: View {
    let team: Team
    let gameService: GameService
    @Environment(\.presentationMode) var presentationMode
    @State private var title = ""
    @State private var artist = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Your Answer")) {
                    TextField("Song Title", text: $title)
                    TextField("Artist", text: $artist)
                }
                
                Button(action: {
                    gameService.submitAnswer(team: team, title: title, artist: artist)
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Submit")
                        .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Submit Answer")
            .navigationBarItems(trailing: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

struct GameView_Previews: PreviewProvider {
    static var previews: some View {
        GameView()
    }
} 