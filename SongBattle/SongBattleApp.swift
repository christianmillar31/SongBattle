import SwiftUI
import SpotifyiOS

@main
struct SongBattleApp: App {
    @StateObject private var spotifyService = SpotifyService()
    @Environment(\.scenePhase) private var phase
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(spotifyService)
                .onAppear {
                    print("DEBUG: App appeared")
                }
                .onOpenURL { url in
                    print("DEBUG: Received URL: \(url)")
                    let handled = spotifyService.handleURL(url)
                    if !handled {
                        print("DEBUG: URL was not handled by Spotify service")
                    }
                }
                .onChange(of: phase) { phase in
                    print("DEBUG: Scene phase changed to: \(phase)")
                    switch phase {
                    case .active:
                        // Don't automatically connect - let user initiate connection
                        break
                    case .background:
                        // Only disconnect if we're not in the middle of auth
                        if spotifyService.authenticationError == nil {
                            spotifyService.disconnect()
                        } else {
                            print("DEBUG: Skipping disconnect during auth")
                        }
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