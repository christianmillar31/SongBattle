import Foundation

struct MusicCategory: Identifiable, Hashable {
    let id: String
    let name: String
    let type: CategoryType
    
    enum CategoryType {
        case genre
        case decade
    }
    
    init(id: String, name: String, type: CategoryType) {
        self.id = id
        self.name = name
        self.type = type
    }
    
    static let genres: [MusicCategory] = [
        MusicCategory(id: "pop", name: "Pop", type: .genre),
        MusicCategory(id: "rock", name: "Rock", type: .genre),
        MusicCategory(id: "hiphop", name: "Hip Hop", type: .genre),
        MusicCategory(id: "r&b", name: "R&B", type: .genre),
        MusicCategory(id: "country", name: "Country", type: .genre),
        MusicCategory(id: "electronic", name: "Electronic", type: .genre),
        MusicCategory(id: "jazz", name: "Jazz", type: .genre),
        MusicCategory(id: "classical", name: "Classical", type: .genre),
        MusicCategory(id: "indie", name: "Indie", type: .genre),
        MusicCategory(id: "metal", name: "Metal", type: .genre)
    ]
    
    static let decades: [MusicCategory] = [
        MusicCategory(id: "2020s", name: "2020s", type: .decade),
        MusicCategory(id: "2010s", name: "2010s", type: .decade),
        MusicCategory(id: "2000s", name: "2000s", type: .decade),
        MusicCategory(id: "1990s", name: "1990s", type: .decade),
        MusicCategory(id: "1980s", name: "1980s", type: .decade),
        MusicCategory(id: "1970s", name: "1970s", type: .decade),
        MusicCategory(id: "1960s", name: "1960s", type: .decade),
        MusicCategory(id: "1950s", name: "1950s", type: .decade)
    ]
    
    static var allCategories: [MusicCategory] {
        genres + decades
    }
} 