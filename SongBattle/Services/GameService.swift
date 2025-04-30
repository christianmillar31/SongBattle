import Foundation
import Combine

@MainActor
class GameService: ObservableObject {
    @Published var currentRound: Round?
    @Published var teams: [Team] = []
    @Published var gameState: GameState = .notStarted
    
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
    
    private func setupSubscriptions() {
        spotifyService.$isConnected
            .combineLatest(spotifyService.$currentTrack)
            .receive(on: RunLoop.main)
            .sink { [weak self] isConnected, track in
                if isConnected, let track = track {
                    self?.updateCurrentRound(with: track)
                }
            }
            .store(in: &cancellables)
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
        // Play a random song
        spotifyService.playRandomSong()
        
        // Create new round
        currentRound = Round(
            id: UUID(),
            song: nil, // Will be updated when track starts playing
            startTime: Date()
        )
    }
    
    func submitScores(team1Title: Bool, team1Artist: Bool, team2Title: Bool, team2Artist: Bool) {
        guard let round = currentRound, round.song != nil else { return }
        
        // Award points to team 1
        if team1Title {
            teams[0].incrementScore()
        }
        if team1Artist {
            teams[0].incrementScore()
        }
        
        // Award points to team 2
        if team2Title {
            teams[1].incrementScore()
        }
        if team2Artist {
            teams[1].incrementScore()
        }
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
