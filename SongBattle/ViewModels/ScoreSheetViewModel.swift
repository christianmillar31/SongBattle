import Foundation
import SwiftUI

@MainActor
class ScoreSheetViewModel: ObservableObject {
    @Published var team1Title = false
    @Published var team1Artist = false
    @Published var team2Title = false
    @Published var team2Artist = false
    
    let gameService: GameService
    let spotifyService: SpotifyService
    
    init(gameService: GameService, spotifyService: SpotifyService) {
        self.gameService = gameService
        self.spotifyService = spotifyService
    }
    
    func submitScores() async {
        await gameService.submitScores(
            team1Title: team1Title,
            team1Artist: team1Artist,
            team2Title: team2Title,
            team2Artist: team2Artist
        )
        resetScores()
    }
    
    func resetScores() {
        team1Title = false
        team1Artist = false
        team2Title = false
        team2Artist = false
    }
    
    var currentSong: Track? {
        get async {
            await gameService.currentRound?.song
        }
    }
    
    var team1: Team? {
        get async {
            await gameService.teams.first
        }
    }
    
    var team2: Team? {
        get async {
            let teams = await gameService.teams
            return teams.count > 1 ? teams[1] : nil
        }
    }
} 