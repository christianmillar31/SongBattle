import SwiftUI

struct GameView: View {
    @EnvironmentObject var gameService: GameService
    @StateObject private var viewModel: GameViewModel
    @State private var showingScoreSheet = false
    @State private var showingAddTeam = false
    @State private var showingCategorySelection = false
    
    init() {
        _viewModel = StateObject(wrappedValue: GameViewModel(gameService: GameService(spotifyService: SpotifyService.shared)))
    }
    
    var body: some View {
        ZStack {
            Color.theme.backgroundColor.ignoresSafeArea()
            VStack {
                if viewModel.isLoading {
                    ProgressView("Loading...")
                } else if viewModel.gameState == .notStarted {
                    startGameView
                } else if viewModel.gameState == .inProgress {
                    gameInProgressView
                } else {
                    gameFinishedView
                }
            }
        }
    }
    
    private var startGameView: some View {
        VStack(spacing: 20) {
            Text("Welcome to SongSmash!")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundColor(Color.theme.primaryText)
                .padding(.top, 8)
            // Team Management Section
            VStack(spacing: 15) {
                Text("Teams")
                    .font(.headline)
                    .foregroundColor(Color.theme.primaryText)
                ForEach(viewModel.teams) { team in
                    HStack {
                        Text(team.name)
                            .foregroundColor(Color.theme.primaryText)
                            .font(.body)
                        Spacer()
                        Button(action: {
                            Task {
                                await viewModel.removeTeam(team)
                            }
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.horizontal)
                }
                Button(action: { showingAddTeam = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Team")
                    }
                }
                .lightButtonStyle()
            }
            .padding(24)
            .background(Color.theme.cardBackground)
            .cornerRadius(20)
            .shadow(color: Color.theme.cardShadow, radius: 8, x: 0, y: 4)
            // Music Categories Section
            VStack(spacing: 15) {
                HStack {
                    Text("Music Categories")
                        .font(.headline)
                        .foregroundColor(Color.theme.primaryText)
                    Spacer()
                    Button(action: { showingCategorySelection = true }) {
                        Text("Select")
                    }
                    .lightButtonStyle()
                    .frame(height: 36)
                }
                if viewModel.selectedCategories.isEmpty {
                    Text("No categories selected - all music will be included")
                        .foregroundColor(Color.theme.primaryText.opacity(0.7))
                        .font(.body)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(viewModel.selectedCategories)) { category in
                                Text(category.name)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.theme.accentColor)
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
            }
            .padding(24)
            .background(Color.theme.cardBackground)
            .cornerRadius(20)
            .shadow(color: Color.theme.cardShadow, radius: 8, x: 0, y: 4)
            if viewModel.canStartGame {
                Button(action: {
                    Task {
                        await viewModel.startGame()
                    }
                }) {
                    Text("Start Game")
                }
                .lightButtonStyle()
                .padding(.top, 8)
            } else {
                Text("Add at least 2 teams to start playing")
                    .foregroundColor(Color.theme.primaryText.opacity(0.7))
                    .font(.body)
            }
        }
        .padding()
        .sheet(isPresented: $showingAddTeam) {
            AddTeamView(viewModel: TeamsViewModel(gameService: viewModel.gameService))
        }
        .sheet(isPresented: $showingCategorySelection) {
            CategorySelectionView(gameService: viewModel.gameService)
        }
    }
    
    private var gameInProgressView: some View {
        VStack {
            if let round = viewModel.currentRound {
                VStack(spacing: 20) {
                    if let song = round.song {
                        SongDisplayView(song: song, isPlaying: viewModel.isPlaying)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color.black.opacity(0.3))
                                    .padding()
                            )
                    } else {
                        ProgressView("Loading song...")
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    Button(action: { showingScoreSheet = true }) {
                        Text("Submit Scores")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.theme.accent)
                            .cornerRadius(10)
                    }
                    .padding()
                }
            }
        }
        .sheet(isPresented: $showingScoreSheet) {
            ScoreSheetView(viewModel: ScoreSheetViewModel(gameService: viewModel.gameService, spotifyService: viewModel.spotifyService))
        }
    }
    
    private var gameFinishedView: some View {
        VStack(spacing: 20) {
            Text("Game Over!")
                .font(.title)
                .foregroundColor(.white)
            
            ForEach(viewModel.sortedTeams) { team in
                Text("\(team.name): \(team.score) points")
                    .foregroundColor(.white)
            }
            
            Button(action: {
                Task {
                    await viewModel.startNewGame()
                }
            }) {
                Text("Start New Game")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.theme.accent)
                    .cornerRadius(10)
            }
            .padding()
        }
        .padding()
    }
}

struct SongDisplayView: View {
    let song: Track
    let isPlaying: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Now Playing")
                .font(.headline)
                .foregroundColor(.white.opacity(0.8))
            
            Text(song.name)
                .font(.title)
                .bold()
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            Text(song.artist)
                .font(.title2)
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.center)
            
            if isPlaying {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.2)
            }
        }
        .padding()
    }
}

#Preview {
    GameView()
}
