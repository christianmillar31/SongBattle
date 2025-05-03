import Foundation
import SwiftUI

@MainActor
final class TeamsViewModel: ObservableObject {
    @Published var teamName: String = ""
    private let gameService: GameService
    @Published private(set) var teams: [Team] = []
    
    init(gameService: GameService) {
        self.gameService = gameService
        // Initialize teams
        Task {
            await updateTeams()
        }
    }
    
    private func updateTeams() async {
        teams = gameService.getTeams()
        print("[TeamsViewModel] updateTeams: teams = \(teams.map { $0.name })")
    }
    
    func addTeam() async {
        guard !teamName.isEmpty else { return }
        let newTeam = Team(id: UUID().uuidString, name: teamName)
        print("[TeamsViewModel] addTeam: adding \(teamName)")
        gameService.appendTeam(newTeam)
        await updateTeams()
        teamName = ""
    }
    
    func removeTeam(_ team: Team) async {
        gameService.removeTeam(team)
        await updateTeams()
    }
} 