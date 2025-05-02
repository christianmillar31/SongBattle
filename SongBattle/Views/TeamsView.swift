import SwiftUI

@MainActor
class TeamsViewModel: ObservableObject {
    @Published var teams: [Team] = []
    private var gameService: GameService
    
    init(gameService: GameService) {
        self.gameService = gameService
        // Initialize teams from gameService
        self.teams = gameService.teams
    }
    
    func addTeam(name: String) {
        let newTeam = Team(id: UUID().uuidString, name: name)
        teams.append(newTeam)
        updateGameServiceTeams()
    }
    
    func deleteTeam(at offsets: IndexSet) {
        teams.remove(atOffsets: offsets)
        updateGameServiceTeams()
    }
    
    private func updateGameServiceTeams() {
        // Since we're already on MainActor, no need for async/await
        gameService.teams = teams
    }
}

struct TeamsView: View {
    @StateObject private var viewModel: TeamsViewModel
    @State private var showingAddTeam = false
    
    init(gameService: GameService) {
        _viewModel = StateObject(wrappedValue: TeamsViewModel(gameService: gameService))
    }
    
    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.teams) { team in
                    TeamRow(team: team)
                }
                .onDelete(perform: viewModel.deleteTeam)
            }
            .navigationTitle("Teams")
            .toolbar {
                Button(action: { showingAddTeam = true }) {
                    Image(systemName: "plus")
                }
            }
            .sheet(isPresented: $showingAddTeam) {
                AddTeamView(viewModel: viewModel)
            }
        }
    }
}

struct TeamRow: View {
    let team: Team
    
    var body: some View {
        HStack {
            Text(team.name)
            Spacer()
            Text("Score: \(team.score)")
                .foregroundColor(.secondary)
        }
    }
}

struct AddTeamView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: TeamsViewModel
    @State private var teamName = ""
    
    var body: some View {
        NavigationView {
            Form {
                TextField("Team Name", text: $teamName)
            }
            .navigationTitle("Add Team")
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button("Save") {
                    viewModel.addTeam(name: teamName)
                    dismiss()
                }
                .disabled(teamName.isEmpty)
            )
        }
    }
}

struct TeamsView_Previews: PreviewProvider {
    static var previews: some View {
        TeamsView(gameService: GameService(spotifyService: SpotifyService.shared))
    }
} 
