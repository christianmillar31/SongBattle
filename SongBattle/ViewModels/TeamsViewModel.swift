import Foundation
import SwiftUI

@MainActor
class TeamsViewModel: ObservableObject {
    @Published var teamName: String = ""
    let gameService: GameService
    
    init(gameService: GameService) {
        self.gameService = gameService
    }
    
    func addTeam() async {
        guard !teamName.isEmpty else { return }
        let newTeam = Team(id: UUID().uuidString, name: teamName)
        await gameService.teams.append(newTeam)
        teamName = ""
    }
    
    func removeTeam(_ team: Team) async {
        if let index = await gameService.teams.firstIndex(where: { $0.id == team.id }) {
            await gameService.teams.remove(at: index)
        }
    }
} 