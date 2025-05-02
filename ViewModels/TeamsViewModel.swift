import Foundation
import SwiftUI

@MainActor
final class TeamsViewModel: ObservableObject {
    @Published var teamName: String = ""
    private let gameService: GameService
    
    init(gameService: GameService) {
        self.gameService = gameService
    }
    
    func addTeam() async {
        guard !teamName.isEmpty else { return }
        let newTeam = Team(id: UUID().uuidString, name: teamName)
        await gameService.appendTeam(newTeam)
        teamName = ""
    }
    
    func removeTeam(_ team: Team) async {
        await gameService.removeTeam(team)
    }
    
    var teams: [Team] {
        get async {
            await gameService.getTeams()
        }
    }
} 