import SwiftUI

struct ScoreSheetView: View {
    @EnvironmentObject var gameService: GameService
    @Environment(\.presentationMode) var presentationMode
    
    // Create two arrays that match the number of teams
    @State private var titleToggles: [Bool]
    @State private var artistToggles: [Bool]
    
    init() {
        // Initialize the toggle arrays with the correct count
        let count = 2 // Default to 2 for initial state
        _titleToggles = State(initialValue: Array(repeating: false, count: count))
        _artistToggles = State(initialValue: Array(repeating: false, count: count))
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
                    // Award points safely using the toggle arrays
                    gameService.submitScores(
                        team1Title: titleToggles.first ?? false,
                        team1Artist: artistToggles.first ?? false,
                        team2Title: titleToggles.dropFirst().first ?? false,
                        team2Artist: artistToggles.dropFirst().first ?? false
                    )
                    gameService.startNewRound()
                    presentationMode.wrappedValue.dismiss()
                }
                .disabled(gameService.teams.count < 2)
            }
            .navigationTitle("Submit Scores")
            .navigationBarItems(trailing: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
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
        .environmentObject(GameService())
} 