import SwiftUI

struct ScoreSheetView: View {
    @EnvironmentObject var gameService: GameService
    @Environment(\.dismiss) var dismiss
    @State private var titleToggles: [Bool]
    @State private var artistToggles: [Bool]
    
    init() {
        // Initialize the toggle arrays with the correct count
        // We'll update these in onAppear if needed
        _titleToggles = State(initialValue: [])
        _artistToggles = State(initialValue: [])
    }
    
    var body: some View {
        NavigationView {
            Form {
                ForEach(Array(gameService.teams.enumerated()), id: \.element.id) { idx, team in
                    Section(header: Text(team.name)) {
                        Toggle("Got Title", isOn: binding(for: $titleToggles, at: idx))
                        Toggle("Got Artist", isOn: binding(for: $artistToggles, at: idx))
                    }
                }
                
                Button("Next Song") {
                    // Submit scores for all teams
                    for (index, team) in gameService.teams.enumerated() {
                        let gotTitle = index < titleToggles.count ? titleToggles[index] : false
                        let gotArtist = index < artistToggles.count ? artistToggles[index] : false
                        
                        if gotTitle {
                            team.incrementScore()
                        }
                        if gotArtist {
                            team.incrementScore()
                        }
                    }
                    
                    // Start new round and play a new song
                    gameService.startNewRound()
                    dismiss()
                }
                .disabled(gameService.teams.count < 2)
            }
            .navigationTitle("Submit Scores")
            .navigationBarItems(trailing: Button("Cancel") {
                dismiss()
            })
            .onAppear {
                // Initialize toggle arrays with the correct team count
                titleToggles = Array(repeating: false, count: gameService.teams.count)
                artistToggles = Array(repeating: false, count: gameService.teams.count)
            }
        }
    }
    
    // Helper function to create safe bindings for toggle arrays
    private func binding(for array: Binding<[Bool]>, at index: Int) -> Binding<Bool> {
        Binding(
            get: {
                guard index < array.wrappedValue.count else { return false }
                return array.wrappedValue[index]
            },
            set: { newValue in
                guard index < array.wrappedValue.count else { return }
                array.wrappedValue[index] = newValue
            }
        )
    }
}

#Preview {
    ScoreSheetView()
        .environmentObject(GameService(spotifyService: SpotifyService()))
} 