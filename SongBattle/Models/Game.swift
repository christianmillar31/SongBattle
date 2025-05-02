import Foundation

class Game {
    var teams: [Team]
    var currentRound: Int
    var maxRounds: Int
    var isGameOver: Bool
    
    init(teams: [Team], maxRounds: Int = 5) {
        self.teams = teams
        self.currentRound = 1
        self.maxRounds = maxRounds
        self.isGameOver = false
    }
    
    func nextRound() {
        if currentRound < maxRounds {
            currentRound += 1
        } else {
            isGameOver = true
        }
    }
    
    func getWinningTeam() -> Team? {
        guard isGameOver else { return nil }
        return teams.max(by: { $0.score < $1.score })
    }
    
    func resetGame() {
        currentRound = 1
        isGameOver = false
        teams.forEach { team in
            // Reset by creating a new team with the same ID and name
            // This automatically resets both score and tracks to empty
            let newTeam = Team(id: team.id, name: team.name)
            if let index = teams.firstIndex(where: { $0.id == team.id }) {
                teams[index] = newTeam
            }
        }
    }
} 