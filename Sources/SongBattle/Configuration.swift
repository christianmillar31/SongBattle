import Foundation
import SwiftUI
 
public enum Configuration {
    @AppStorage("spotifyClientId") public static var spotifyClientId: String = ""
    public static let spotifyRedirectURI = "songbattle://spotify-callback"
} 