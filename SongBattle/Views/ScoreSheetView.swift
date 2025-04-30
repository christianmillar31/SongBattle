import SwiftUI

struct ScoreSheetView: View {
    @EnvironmentObject var gameService: GameService
    @Environment(\.presentationMode) var presentationMode
    
    // Create two arrays that match the number of teams
    @State private var titleToggles: [Bool]
    @State private var artistToggles: [Bool]
    
    init() {
        // Initialize the toggle arrays with the correct count
        _titleToggles = State(initialValue: Array(repeating: false, count: 2))
        _artistToggles = State(initialValue: Array(repeating: false, count: 2))
    }
    
    var body: some View {
        NavigationView {
            Form {
                if gameService.teams.count >= 2 {
                    ForEach(Array(gameService.teams.enumerated()), id: \.element.id) { idx, team in
                        Section(header: Text(team.name)) {
                            Toggle("Got Title", isOn: binding(for: $titleToggles, at: idx))
                            Toggle("Got Artist", isOn: binding(for: $artistToggles, at: idx))
                        }
                    }
                    
                    Button("Next Song") {
                        // Award points safely using the toggle arrays
                        gameService.submitScores(
                            team1Title: titleToggles[0],
                            team1Artist: artistToggles[0],
                            team2Title: titleToggles[1],
                            team2Artist: artistToggles[1]
                        )
                        gameService.startNewRound()
                        presentationMode.wrappedValue.dismiss()
                    }
                } else {
                    Text("At least 2 teams are required to play")
                        .foregroundColor(.secondary)
                }
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