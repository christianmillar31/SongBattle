import SwiftUI

struct TeamsView: View {
    @StateObject private var viewModel: TeamsViewModel
    @State private var showingAddTeam = false
    
    init(gameService: GameService) {
        _viewModel = StateObject(wrappedValue: TeamsViewModel(gameService: gameService))
    }
    
    var body: some View {
        List {
            ForEach(viewModel.teams) { team in
                TeamRow(team: team)
            }
            .onDelete { indexSet in
                Task {
                    for index in indexSet {
                        await viewModel.removeTeam(viewModel.teams[index])
                    }
                }
            }
            
            Button(action: { showingAddTeam = true }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Team")
                }
            }
        }
        .sheet(isPresented: $showingAddTeam) {
            AddTeamView(viewModel: viewModel)
        }
    }
}

struct TeamRow: View {
    let team: Team
    
    var body: some View {
        HStack {
            Text(team.name)
            Spacer()
        }
    }
}

struct TeamsView_Previews: PreviewProvider {
    static var previews: some View {
        TeamsView(gameService: GameService(spotifyService: SpotifyService.shared))
            .environmentObject(GameService(spotifyService: SpotifyService.shared))
    }
}

