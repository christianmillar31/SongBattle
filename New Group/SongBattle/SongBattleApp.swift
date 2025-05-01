import SwiftUI
import SpotifyiOS

@main
struct SongBattleApp: App {
    @StateObject private var spotifyService = SpotifyService()
    @State private var isLoading = true
    @Environment(\.scenePhase) var phase
    
    var body: some Scene {
        WindowGroup {
            // Temporary: Show IconGeneratorView for testing
            IconGeneratorView()
            
            // Comment out the normal app flow temporarily
            /*
            ZStack {
                if isLoading {
                    LoadingView()
                        .transition(.opacity)
                } else {
                    ContentView()
                        .environmentObject(spotifyService)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut, value: isLoading)
            .onAppear {
                // Simulate loading time and initialize services
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation {
                        isLoading = false
                    }
                }
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
            */
        }
    }
} 