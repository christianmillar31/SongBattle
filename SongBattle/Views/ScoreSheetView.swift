import SwiftUI

struct ScoreSheetView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var viewModel: ScoreSheetViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            if let currentSong = viewModel.currentSong {
                Text("Current Song")
                    .font(.headline)
                Text(currentSong.name)
                    .font(.title)
                Text(currentSong.artist)
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            if let team1 = viewModel.team1, let team2 = viewModel.team2 {
                TeamScoreSection(
                    teamName: team1.name,
                    titleToggle: $viewModel.team1Title,
                    artistToggle: $viewModel.team1Artist
                )
                
                TeamScoreSection(
                    teamName: team2.name,
                    titleToggle: $viewModel.team2Title,
                    artistToggle: $viewModel.team2Artist
                )
                
                Button(action: {
                    Task {
                        await viewModel.submitScores()
                        await viewModel.gameService.startNewRound()
                        presentationMode.wrappedValue.dismiss()
                    }
                }) {
                    Text("Submit Scores")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding()
            } else {
                Text("At least 2 teams are required to play")
                    .foregroundColor(.red)
            }
        }
        .padding()
    }
}

struct TeamScoreSection: View {
    let teamName: String
    @Binding var titleToggle: Bool
    @Binding var artistToggle: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(teamName)
                .font(.headline)
            
            Toggle("Correct Title", isOn: $titleToggle)
            Toggle("Correct Artist", isOn: $artistToggle)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
    }
}

#Preview {
    let spotifyService = SpotifyService.shared
    let gameService = GameService(spotifyService: spotifyService)
    ScoreSheetView(
        viewModel: ScoreSheetViewModel(gameService: gameService, spotifyService: spotifyService)
    )
        .environmentObject(spotifyService)
        .environmentObject(gameService)
} 