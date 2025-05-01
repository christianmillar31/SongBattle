import Foundation

struct Track: Identifiable {
    let id: String
    let name: String
    let artist: String
    let previewUrl: String?
    let albumArtUrl: String?
    
    init(id: String, name: String, artist: String, previewUrl: String? = nil, albumArtUrl: String? = nil) {
        self.id = id
        self.name = name
        self.artist = artist
        self.previewUrl = previewUrl
        self.albumArtUrl = albumArtUrl
    }
} 