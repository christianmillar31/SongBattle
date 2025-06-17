import SwiftUI

struct ContentView: View {
    @EnvironmentObject var spotifyService: SpotifyService
    @EnvironmentObject var gameService: GameService
    @State private var isLoading = true
    @State private var showingSettings = false
    @State private var showSongSelection = false
    @State private var isFetchingTracks = false
    @State private var fetchError: String? = nil
    @State private var fetchedTracks: [Track] = []
    @State private var selectedGenre: String = "Pop"
    @State private var selectedDecade: String = "2020s"
    @State private var selectedDifficulty: String = "Easy"
    @State private var isGameActive = false
    
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
                } else if isFetchingTracks {
                    VStack {
                        ProgressView("Fetching songs...")
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .foregroundColor(.white)
                        if let fetchError = fetchError {
                            Text(fetchError)
                                .foregroundColor(.red)
                                .padding()
                        }
                    }
                } else if showSongSelection {
                    SongSelectionView(onStart: { genre, decade, difficulty in
                        selectedGenre = genre
                        selectedDecade = decade
                        selectedDifficulty = difficulty
                        fetchTracksAndStartGame()
                    })
                } else {
                    VStack(spacing: 20) {
                        Text("SongSmash")
                            .font(.largeTitle.bold())
                            .foregroundColor(.white)
                        TeamsView(gameService: gameService)
                        Button(action: {
                            showSongSelection = true
                        }) {
                            Text("Start Game")
                                .font(.title3.weight(.semibold))
                        }
                        .primaryButtonStyle()
                        .disabled(!spotifyService.isConnected || gameService.teams.count < 2)
                    }
                    .padding()
                }
            }
            .navigationTitle("SongSmash")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gear")
                            .font(.title3.weight(.semibold))
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .background(
                NavigationLink(
                    destination: GameView(gameService: gameService),
                    isActive: $isGameActive,
                    label: { EmptyView() }
                )
            )
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
    
    private func fetchTracksAndStartGame() {
        guard spotifyService.isConnected else {
            fetchError = "Spotify is not connected. Please connect to Spotify and try again."
            print("DEBUG: Cannot start game, Spotify is not connected.")
            return
        }
        isFetchingTracks = true
        fetchError = nil
        fetchedTracks = []
        print("DEBUG: Starting fetchTracksAndStartGame with genre: \(selectedGenre), decade: \(selectedDecade), difficulty: \(selectedDifficulty)")
        Task {
            do {
                // Build a MusicCategory for the selected genre/decade
                let category: MusicCategory
                if selectedGenre != "" {
                    category = MusicCategory(id: selectedGenre, name: selectedGenre, type: .genre)
                } else {
                    category = MusicCategory(id: selectedDecade, name: selectedDecade, type: .decade)
                }
                print("DEBUG: Created category: \(category)")
                let tracks = try await spotifyService.getTracksForCategory(category, difficulty: selectedDifficulty)
                print("DEBUG: getTracksForCategory returned \(tracks?.count ?? 0) tracks")
                if let tracks = tracks, !tracks.isEmpty {
                    fetchedTracks = tracks
                    print("DEBUG: Setting tracks in gameService and proceeding to game view")
                    gameService.setTracks(tracks)
                    isFetchingTracks = false
                    showSongSelection = false
                    isGameActive = true
                } else {
                    fetchError = "No tracks found. Try a different selection."
                    print("DEBUG: No tracks found for selection")
                    isFetchingTracks = false
                }
            } catch {
                fetchError = "Failed to fetch tracks: \(error.localizedDescription)"
                print("DEBUG: Error in fetchTracksAndStartGame: \(error)")
                isFetchingTracks = false
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(SpotifyService.shared)
        .environmentObject(GameService(spotifyService: SpotifyService.shared))
}

