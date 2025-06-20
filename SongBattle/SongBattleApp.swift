import SwiftUI
import SpotifyiOS

@main
struct SongBattleApp: App {
    @StateObject private var spotifyService = SpotifyService.shared
    @StateObject private var gameService = GameService(spotifyService: SpotifyService.shared)
    @Environment(\.scenePhase) var phase
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(spotifyService)
                .environmentObject(gameService)
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
                .onChange(of: phase) { newPhase in
                    print("DEBUG: Scene phase changed to: \(newPhase)")
                    switch newPhase {
                    case .active:
                        // Don't automatically connect - let user initiate connection
                        break
                    case .background:
                        // Only disconnect if we're not in the middle of auth
                        if !spotifyService.isConnecting {
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