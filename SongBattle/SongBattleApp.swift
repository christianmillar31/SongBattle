import SwiftUI
import SpotifyiOS

@main
struct SongBattleApp: App {
    @StateObject private var spotifyService = SpotifyService()
    @Environment(\.scenePhase) var phase
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(spotifyService)
                .onAppear {
                    print("DEBUG: App appeared")
                }
                .onOpenURL { url in
                    print("DEBUG: Received URL: \(url)")
                    spotifyService.handleURL(url)
                }
                .onChange(of: phase) { newPhase in
                    print("DEBUG: Scene phase changed to: \(newPhase)")
                    switch newPhase {
                    case .active:
                        // Don't automatically connect - let user initiate connection
                        break
                    case .background:
                        // Clean up Spotify resources when going to background
                        spotifyService.disconnect()
                    case .inactive:
                        // App is transitioning between states, no action needed
                        break
                    @unknown default:
                        break
                    }
                }
        }
    }
} 