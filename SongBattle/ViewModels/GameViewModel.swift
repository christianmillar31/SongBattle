import Foundation
import SwiftUI

@MainActor
final class GameViewModel: ObservableObject {
    @Published var isLoading = true
    @Published private(set) var teams: [Team] = []
    @Published private(set) var currentRound: Round?
    @Published private(set) var gameState: GameService.GameState = .notStarted
    @Published private(set) var selectedCategories: Set<MusicCategory> = []
    @Published private(set) var sortedTeams: [Team] = []
    @Published private(set) var isPlaying = false
    
    let gameService: GameService
    var spotifyService: SpotifyService { gameService.spotifyService }
    
    init(gameService: GameService) {
        self.gameService = gameService
        Task {
            print("[GameViewModel] INIT: teams count = \(gameService.getTeams().count)")
            await updateGameState()
            isLoading = false
        }
    }
    
    private func updateGameState() async {
        teams = gameService.getTeams()
        currentRound = gameService.currentRound
        gameState = gameService.gameState
        selectedCategories = gameService.selectedCategories
        sortedTeams = teams.sorted { $0.score > $1.score }
        isPlaying = spotifyService.isPlaying
        print("[GameViewModel] updateGameState: teams = \(teams.map { $0.name }), gameState = \(gameState)")
    }
    
    var canStartGame: Bool {
        print("[GameViewModel] canStartGame: teams.count = \(teams.count)")
        return teams.count >= 2
    }
    
    func startGame() async {
        print("[GameViewModel] startGame called")
        await gameService.startGame()
        await updateGameState()
        print("[GameViewModel] startGame finished: gameState = \(gameState)")
    }
    
    func startNewGame() async {
        print("[GameViewModel] startNewGame called")
        gameService.endGame()
        await startGame()
    }
    
    func removeTeam(_ team: Team) async {
        print("[GameViewModel] removeTeam called for \(team.name)")
        gameService.removeTeam(team)
        await updateGameState()
    }
} 