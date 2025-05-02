import SwiftUI

struct TeamsView: View {
    @StateObject private var viewModel: TeamsViewModel
    @State private var showingAddTeam = false
    @State private var teams: [Team] = []
    
    init(gameService: GameService) {
        _viewModel = StateObject(wrappedValue: TeamsViewModel(gameService: gameService))
    }
    
    var body: some View {
        List {
            ForEach(teams) { team in
                TeamRow(team: team)
            }
            .onDelete { indexSet in
                Task {
                    for index in indexSet {
                        await viewModel.removeTeam(teams[index])
                    }
                    // Update local teams after deletion
                    teams = await viewModel.teams
                }
            }
            
            Button(action: { showingAddTeam = true }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Team")
                }
            }
        }
        .task {
            // Initial load of teams
            teams = await viewModel.teams
        }
        .sheet(isPresented: $showingAddTeam) {
            AddTeamView(viewModel: viewModel, teams: $teams)
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
    @Binding var teams: [Team]
    
    var body: some View {
        NavigationView {
            Form {
                TextField("Team Name", text: $viewModel.teamName)
            }
            .navigationTitle("Add Team")
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button("Add") {
                    Task {
                        await viewModel.addTeam()
                        // Update local teams after addition
                        teams = await viewModel.teams
                        dismiss()
                    }
                }
                .disabled(viewModel.teamName.isEmpty)
            )
        }
    }
} 