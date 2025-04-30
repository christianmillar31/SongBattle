import Foundation

enum Configuration {
    static var spotifyClientId: String {
        // Replace with your actual client ID from Spotify Developer Dashboard
        return "1a71b9e3c3c44b41b6f6ea0c616b3083"
    }
    
    static let spotifyRedirectURI = "songbattle://spotify-callback"
    
    // Add any other configuration values here
} 