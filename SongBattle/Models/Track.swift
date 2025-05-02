import Foundation

struct Track: Identifiable, Hashable {
    let id: String
    let name: String
    let artist: String
    let previewUrl: String?
    let albumArtUrl: String?
    let uri: String
    
    init(id: String, name: String, artist: String, uri: String, previewUrl: String? = nil, albumArtUrl: String? = nil) {
        self.id = id
        self.name = name
        self.artist = artist
        self.uri = uri
        self.previewUrl = previewUrl
        self.albumArtUrl = albumArtUrl
    }
    
    // Implement Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Track, rhs: Track) -> Bool {
        lhs.id == rhs.id
    }
} 