import SwiftUI

struct TeamsView: View {
    @StateObject private var viewModel = TeamsViewModel()
    @State private var showingAddTeam = false
    
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
            Text("\(team.score)")
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
        TeamsView()
    }
} 