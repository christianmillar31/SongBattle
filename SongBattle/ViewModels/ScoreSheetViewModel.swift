import Foundation
import SwiftUI

@MainActor
final class ScoreSheetViewModel: ObservableObject {
    @Published var team1Title = false
    @Published var team1Artist = false
    @Published var team2Title = false
    @Published var team2Artist = false
    
    @Published private(set) var currentSong: Track?
    @Published private(set) var team1: Team?
    @Published private(set) var team2: Team?
    
    let gameService: GameService
    let spotifyService: SpotifyService
    
    init(gameService: GameService, spotifyService: SpotifyService) {
        self.gameService = gameService
        self.spotifyService = spotifyService
        
        Task {
            await updateGameState()
        }
    }
    
    private func updateGameState() async {
        currentSong = gameService.currentRound?.song
        let teams = gameService.getTeams()
        team1 = teams.first
        team2 = teams.count > 1 ? teams[1] : nil
    }
    
    func submitScores() async {
        gameService.submitScores(
            team1Title: team1Title,
            team1Artist: team1Artist,
            team2Title: team2Title,
            team2Artist: team2Artist
        )
        resetScores()
        await updateGameState()
    }
    
    func resetScores() {
        team1Title = false
        team1Artist = false
        team2Title = false
        team2Artist = false
    }
} 