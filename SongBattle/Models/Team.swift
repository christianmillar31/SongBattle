import Foundation

class Team: Identifiable, ObservableObject {
    let id: String
    let name: String
    @Published private(set) var score: Int
    private(set) var tracks: [Track]
    
    init(id: String, name: String) {
        self.id = id
        self.name = name
        self.score = 0
        self.tracks = []
    }
    
    func addTrack(_ track: Track) {
        tracks.append(track)
    }
    
    func incrementScore() {
        score += 1
    }
    
    func resetScore() {
        score = 0
    }
} 
