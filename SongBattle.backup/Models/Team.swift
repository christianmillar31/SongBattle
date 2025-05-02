import Foundation

class Team: Identifiable {
    let id: String
    let name: String
    private(set) var score: Int
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
} 
