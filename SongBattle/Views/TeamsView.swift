import SwiftUI

struct TeamsView: View {
    @EnvironmentObject var gameService: GameService
    @StateObject private var viewModel: TeamsViewModel
    @State private var showingAddTeam = false
    
    init() {
        _viewModel = StateObject(wrappedValue: TeamsViewModel(gameService: GameService(spotifyService: SpotifyService.shared)))
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
        .onAppear {
            if viewModel.gameService !== gameService {
                viewModel.updateGameService(gameService)
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
        }
    }
}

struct TeamsView_Previews: PreviewProvider {
    static var previews: some View {
        TeamsView()
            .environmentObject(GameService(spotifyService: SpotifyService.shared))
    }
}

