@MainActor
class GameService: ObservableObject {
    @Published var currentRound: Round?
    @Published var teams: [Team] = []
    @Published var gameState: GameState = .notStarted
    @Published var selectedCategories: Set<MusicCategory> = []
    
    func appendTeam(_ team: Team) async {
        teams.append(team)
        objectWillChange.send()
    }
    
    func removeTeam(_ team: Team) async {
        if let index = teams.firstIndex(where: { $0.id == team.id }) {
            teams.remove(at: index)
            objectWillChange.send()
        }
    }
    
    func getTeams() async -> [Team] {
        teams
    }
} 