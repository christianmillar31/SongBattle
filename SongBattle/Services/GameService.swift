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
        // Only subscribe to track changes when Spotify is connected
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
        guard !teams.isEmpty else { return }
        gameState = .inProgress
        startNewRound()
    }
    
    func endGame() {
        gameState = .finished
        currentRound = nil
    }
    
    func startNewRound() {
        let selectedTeam = selectTeamForRound()
        
        Task {
            if let track = spotifyService.currentTrack {
                currentRound = Round(
                    id: UUID(),
                    team: selectedTeam,
                    song: track,
                    startTime: Date(),
                    answers: []
                )
            }
        }
    }
    
    func submitAnswer(team: Team, title: String, artist: String) {
        guard var round = currentRound else { return }
        
        let answer = Answer(
            team: team,
            title: title,
            artist: artist,
            timestamp: Date()
        )
        
        round.answers.append(answer)
        currentRound = round
        
        // Check if all teams have answered
        if round.answers.count == teams.count {
            evaluateRound()
        }
    }
    
    private func selectTeamForRound() -> Team {
        // Implement fair team selection logic
        // For now, just rotate through teams
        let lastTeamIndex = teams.firstIndex(where: { $0.id == currentRound?.team.id }) ?? -1
        let nextIndex = (lastTeamIndex + 1) % teams.count
        return teams[nextIndex]
    }
    
    private func updateCurrentRound(with track: Track) {
        if var round = currentRound {
            round.song = track
            currentRound = round
        }
    }
    
    private func evaluateRound() {
        guard let round = currentRound, let correctTrack = round.song else { return }
        
        // Sort answers by timestamp
        let sortedAnswers = round.answers.sorted { $0.timestamp < $1.timestamp }
        
        // Award points with time bonus
        for (index, answer) in sortedAnswers.enumerated() {
            let basePoints = calculatePoints(answer: answer, correctTrack: correctTrack)
            // Add time bonus: earlier answers get more points
            let timeBonus = max(0, 3 - index) // 3 points for first, 2 for second, 1 for third
            let totalPoints = basePoints + timeBonus
            
            if let teamIndex = teams.firstIndex(where: { $0.id == answer.team.id }) {
                // Add points based on accuracy and speed
                for _ in 0..<totalPoints {
                    teams[teamIndex].incrementScore()
                }
            }
        }
        
        // Start next round after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.startNewRound()
        }
    }
    
    private func calculatePoints(answer: Answer, correctTrack: Track) -> Int {
        var points = 0
        
        // Check title
        if answer.title.lowercased() == correctTrack.name.lowercased() {
            points += 1
        }
        
        // Check artist
        if answer.artist.lowercased() == correctTrack.artist.lowercased() {
            points += 1
        }
        
        return points
    }
}

struct Round: Identifiable {
    let id: UUID
    let team: Team
    var song: Track?
    let startTime: Date
    var answers: [Answer]
}

struct Answer: Identifiable {
    let id = UUID()
    let team: Team
    let title: String
    let artist: String
    let timestamp: Date
} 
