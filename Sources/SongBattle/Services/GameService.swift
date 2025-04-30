import Foundation
import Combine

class GameService: ObservableObject {
    @Published var currentRound: Round?
    @Published var teams: [Team] = []
    @Published var gameState: GameState = .notStarted
    
    private var spotifyService: SpotifyService
    private var cancellables = Set<AnyCancellable>()
    
    enum GameState {
        case notStarted
        case inProgress
        case finished
    }
    
    init(spotifyService: SpotifyService) {
        self.spotifyService = spotifyService
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
        let song = selectRandomSong()
        
        currentRound = Round(
            id: UUID(),
            team: selectedTeam,
            song: song,
            startTime: Date(),
            answers: []
        )
        
        spotifyService.play(track: song)
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
    
    private func selectRandomSong() -> Track {
        // TODO: Implement fair song selection logic
        // For now, return a dummy track
        return Track(
            id: UUID().uuidString,
            title: "Sample Song",
            artist: "Sample Artist",
            uri: "spotify:track:sample"
        )
    }
    
    private func evaluateRound() {
        guard let round = currentRound else { return }
        
        // Sort answers by timestamp
        let sortedAnswers = round.answers.sorted { $0.timestamp < $1.timestamp }
        
        // Award points
        for (index, answer) in sortedAnswers.enumerated() {
            let points = calculatePoints(for: answer, at: index)
            updateTeamScore(team: answer.team, points: points)
        }
        
        // Start next round after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.startNewRound()
        }
    }
    
    private func calculatePoints(for answer: Answer, at position: Int) -> Int {
        var points = 0
        
        // Check title
        if answer.title.lowercased() == round?.song.title.lowercased() {
            points += 1
        }
        
        // Check artist
        if answer.artist.lowercased() == round?.song.artist.lowercased() {
            points += 1
        }
        
        // If first to answer correctly, double points
        if position == 0 && points > 0 {
            points *= 2
        }
        
        return points
    }
    
    private func updateTeamScore(team: Team, points: Int) {
        if let index = teams.firstIndex(where: { $0.id == team.id }) {
            teams[index].score += points
        }
    }
}

struct Round: Identifiable {
    let id: UUID
    let team: Team
    let song: Track
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