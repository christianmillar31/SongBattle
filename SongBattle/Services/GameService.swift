import Foundation
import Combine

@MainActor
class GameService: ObservableObject {
    @Published var currentRound: Round?
    @Published var teams: [Team] = []
    @Published var gameState: GameState = .notStarted
    @Published var selectedCategories: Set<MusicCategory> = []
    
    var spotifyService: SpotifyService
    private var cancellables = Set<AnyCancellable>()
    
    enum GameState {
        case notStarted
        case inProgress
        case finished
    }
    
    init(spotifyService: SpotifyService) {
        self.spotifyService = spotifyService
        setupSubscriptions()
    }
    
    func updateSpotifyService(_ newService: SpotifyService) {
        spotifyService = newService
        cancellables.removeAll()
        setupSubscriptions()
    }
    
    func toggleCategory(_ category: MusicCategory) {
        if selectedCategories.contains(category) {
            selectedCategories.remove(category)
        } else {
            selectedCategories.insert(category)
        }
    }
    
    func clearCategories() {
        selectedCategories.removeAll()
    }
    
    private func setupSubscriptions() {
        // Observe connection state and current track
        spotifyService.$isConnected
            .combineLatest(spotifyService.$currentTrack)
            .receive(on: RunLoop.main)
            .sink { [weak self] isConnected, track in
                if isConnected, let track = track {
                    self?.updateCurrentRound(with: track)
                }
            }
            .store(in: &cancellables)
        
        // Observe playback failures
        spotifyService.$error
            .receive(on: RunLoop.main)
            .sink { [weak self] error in
                if error != nil {
                    // Handle playback error - maybe restart round or show error
                    self?.handlePlaybackError()
                }
            }
            .store(in: &cancellables)
    }
    
    private func handlePlaybackError() {
        // If in a game, try to restart the round or show error
        if gameState == .inProgress {
            startNewRound()
        }
    }
    
    func startGame() {
        guard teams.count >= 2 else { return }
        gameState = .inProgress
        startNewRound()
    }
    
    func endGame() {
        gameState = .finished
        currentRound = nil
    }
    
    func startNewRound() {
        // Create new round first
        currentRound = Round(
            id: UUID(),
            song: nil,
            startTime: Date()
        )
        
        // If we're not connected, wait for connection before playing
        guard spotifyService.isConnected else {
            print("DEBUG: Not connected to Spotify, waiting for connection...")
            // Subscribe for the next "became true" and then re-invoke
            spotifyService.$isConnected
                .filter { $0 }
                .prefix(1)
                .sink { [weak self] _ in
                    print("DEBUG: Spotify connected, starting round...")
                    self?.startNewRound()
                }
                .store(in: &cancellables)
            
            // Kick off a connect (this will be back-off-safe)
            spotifyService.connect()
            return
        }
        
        // Only play random song when we're actually connected
        print("DEBUG: Connected to Spotify, playing random song...")
        if !selectedCategories.isEmpty {
            // Play a song from selected categories
            spotifyService.playRandomSong(from: selectedCategories)
        } else {
            // Play any random song
            spotifyService.playRandomSong()
        }
    }
    
    func submitScores(team1Title: Bool, team1Artist: Bool, team2Title: Bool, team2Artist: Bool) {
        guard let song = currentRound?.song else { return }
        
        print("DEBUG: Scoring guesses for '\(song.name)' by \(song.artist)")
        
        // Track scores for this round
        var team1Score = 0
        var team2Score = 0
        
        // Award points to team 1
        if team1Title {
            teams[0].incrementScore()
            team1Score += 1
            print("DEBUG: Team 1 correctly guessed the title")
        }
        if team1Artist {
            teams[0].incrementScore()
            team1Score += 1
            print("DEBUG: Team 1 correctly guessed the artist")
        }
        
        // Award points to team 2
        if team2Title {
            teams[1].incrementScore()
            team2Score += 1
            print("DEBUG: Team 2 correctly guessed the title")
        }
        if team2Artist {
            teams[1].incrementScore()
            team2Score += 1
            print("DEBUG: Team 2 correctly guessed the artist")
        }
        
        // Log round results
        print("DEBUG: Round complete - Team 1: \(team1Score) points, Team 2: \(team2Score) points")
        print("DEBUG: Total scores - Team 1: \(teams[0].score), Team 2: \(teams[1].score)")
        
        // Force UI update by reassigning teams array
        objectWillChange.send()
        teams = teams
    }
    
    private func updateCurrentRound(with track: Track) {
        if var round = currentRound {
            round.song = track
            currentRound = round
        }
    }
}

struct Round: Identifiable {
    let id: UUID
    var song: Track?
    let startTime: Date
} 
