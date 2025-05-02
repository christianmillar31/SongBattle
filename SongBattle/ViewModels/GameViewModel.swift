import Foundation
import SwiftUI

@MainActor
class GameViewModel: ObservableObject {
    @Published var isLoading = true
    @Published var showingScoreSheet = false
    @Published var showingAddTeam = false
    @Published var showingCategorySelection = false
    
    let gameService: GameService
    
    init(gameService: GameService) {
        self.gameService = gameService
    }
    
    func startGame() async {
        await gameService.startGame()
    }
    
    func finishLoading() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.isLoading = false
        }
    }
    
    var canStartGame: Bool {
        get async {
            await gameService.teams.count >= 2
        }
    }
    
    var sortedTeams: [Team] {
        get async {
            await gameService.teams.sorted { $0.score > $1.score }
        }
    }
} 