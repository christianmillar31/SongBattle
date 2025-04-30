import Foundation

enum Configuration {
    static let bundleId = "com.example.SongBattle"
    
    static var spotifyClientId: String {
        // Replace with your actual client ID from Spotify Developer Dashboard
        return "c4788e07ffa548f78f8101af9c8aa0c5"
    }
    
    static let spotifyRedirectURI = "songbattle://spotify-callback"
    
    // Add any other configuration values here
} 