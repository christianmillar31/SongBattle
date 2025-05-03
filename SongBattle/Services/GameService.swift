import Foundation
import Combine

@MainActor
final class GameService: ObservableObject {
    @Published private(set) var currentRound: Round?
    @Published private(set) var teams: [Team] = []
    @Published private(set) var gameState: GameState = .notStarted
    @Published var selectedCategories: Set<MusicCategory> = []
    @Published var tracks: [Track] = []
    
    private let _spotifyService: SpotifyService
    private var cancellables = Set<AnyCancellable>()
    
    var spotifyService: SpotifyService { _spotifyService }
    
    enum GameState {
        case notStarted
        case inProgress
        case finished
    }
    
    init(spotifyService: SpotifyService) {
        self._spotifyService = spotifyService
        setupSubscriptions()
    }
    
    // MARK: - Team Management
    func getTeams() -> [Team] {
        teams
    }
    
    func appendTeam(_ team: Team) {
        teams.append(team)
        print("[GameService] Team added: \(team.name), total teams: \(teams.count)")
        objectWillChange.send()
    }
    
    func removeTeam(_ team: Team) {
        if let index = teams.firstIndex(where: { $0.id == team.id }) {
            teams.remove(at: index)
            objectWillChange.send()
        }
    }
    
    // MARK: - Game Flow
    func startGame() async {
        guard teams.count >= 2 else { return }
        gameState = .inProgress
        await startNewRound()
    }
    
    func endGame() {
        gameState = .finished
        currentRound = nil
    }
    
    // MARK: - Category Management
    func toggleCategory(_ category: MusicCategory) async {
        if selectedCategories.contains(category) {
            selectedCategories.remove(category)
        } else {
            selectedCategories.insert(category)
        }
        objectWillChange.send()
    }
    
    func clearCategories() async {
        selectedCategories.removeAll()
        objectWillChange.send()
    }
    
    // MARK: - Private Methods
    private func setupSubscriptions() {
        // Observe connection state and current track
        _spotifyService.$isConnected
            .combineLatest(_spotifyService.$currentTrack)
            .receive(on: RunLoop.main)
            .sink { [weak self] isConnected, track in
                if isConnected, let track = track {
                    self?.updateCurrentRound(with: track)
                }
            }
            .store(in: &cancellables)
        
        // Observe playback failures
        _spotifyService.$error
            .receive(on: RunLoop.main)
            .sink { [weak self] error in
                if error != nil {
                    self?.handlePlaybackError()
                }
            }
            .store(in: &cancellables)
    }
    
    private func handlePlaybackError() {
        if gameState == .inProgress {
            Task {
                await startNewRound()
            }
        }
    }
    
    private func updateCurrentRound(with track: Track) {
        if var round = currentRound {
            round.song = track
            currentRound = round
        }
    }
    
    func startNewRound() async {
        currentRound = Round(
            id: UUID(),
            song: nil,
            startTime: Date()
        )
        
        guard _spotifyService.isConnected else {
            print("DEBUG: Not connected to Spotify, waiting for connection...")
            _spotifyService.$isConnected
                .filter { $0 }
                .prefix(1)
                .sink { [weak self] _ in
                    print("DEBUG: Spotify connected, starting round...")
                    Task {
                        await self?.startNewRound()
                    }
                }
                .store(in: &cancellables)
            
            _spotifyService.connect()
            return
        }
        
        print("DEBUG: Connected to Spotify, playing random song...")
        if !selectedCategories.isEmpty {
            _spotifyService.playRandomSong(from: selectedCategories)
        } else {
            _spotifyService.playRandomSong()
        }
    }
    
    func submitScores(team1Title: Bool, team1Artist: Bool, team2Title: Bool, team2Artist: Bool) {
        guard let song = currentRound?.song, teams.count >= 2 else { return }
        
        print("DEBUG: Scoring round for song '\(song.name)' by '\(song.artist)'")
        
        // Track scores for this round
        var team1Score = 0
        var team2Score = 0
        
        // Award points to team 1
        if team1Title {
            teams[0].incrementScore()
            team1Score += 1
            print("DEBUG: Team '\(teams[0].name)' got the title '\(song.name)'")
        }
        if team1Artist {
            teams[0].incrementScore()
            team1Score += 1
            print("DEBUG: Team '\(teams[0].name)' got the artist '\(song.artist)'")
        }
        
        // Award points to team 2
        if team2Title {
            teams[1].incrementScore()
            team2Score += 1
            print("DEBUG: Team '\(teams[1].name)' got the title '\(song.name)'")
        }
        if team2Artist {
            teams[1].incrementScore()
            team2Score += 1
            print("DEBUG: Team '\(teams[1].name)' got the artist '\(song.artist)'")
        }
        
        print("DEBUG: Round complete - \(teams[0].name): \(team1Score) points, \(teams[1].name): \(team2Score) points")
        print("DEBUG: Total scores - \(teams[0].name): \(teams[0].score), \(teams[1].name): \(teams[1].score)")
        
        objectWillChange.send()
    }
    
    func setTracks(_ tracks: [Track]) {
        self.tracks = tracks
        objectWillChange.send()
    }
}

struct Round: Identifiable {
    let id: UUID
    var song: Track?
    let startTime: Date
} 
