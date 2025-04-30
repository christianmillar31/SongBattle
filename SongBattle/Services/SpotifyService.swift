import Foundation
import SpotifyiOS
import Combine
import SwiftUI
import UIKit

extension Notification.Name {
    static let spotifyAuthCallback = Notification.Name("spotifyAuthCallback")
}

enum SpotifyError: LocalizedError, Equatable {
    case configurationNotSet
    case connectionFailed(String)
    case playbackError(String)
    case authenticationError(String)
    case connectionTimeout
    case invalidRedirectURI
    
    var errorDescription: String? {
        switch self {
        case .configurationNotSet:
            return "Spotify configuration not set"
        case .connectionFailed(let reason):
            return "Failed to connect: \(reason)"
        case .playbackError(let reason):
            return "Playback error: \(reason)"
        case .authenticationError(let reason):
            return "Authentication error: \(reason)"
        case .connectionTimeout:
            return "Connection attempt timed out"
        case .invalidRedirectURI:
            return "Invalid redirect URI. Please check your Spotify Developer Dashboard settings."
        }
    }
    
    static func == (lhs: SpotifyError, rhs: SpotifyError) -> Bool {
        switch (lhs, rhs) {
        case (.configurationNotSet, .configurationNotSet):
            return true
        case (.connectionFailed(let lhsReason), .connectionFailed(let rhsReason)):
            return lhsReason == rhsReason
        case (.playbackError(let lhsReason), .playbackError(let rhsReason)):
            return lhsReason == rhsReason
        case (.authenticationError(let lhsReason), .authenticationError(let rhsReason)):
            return lhsReason == rhsReason
        case (.connectionTimeout, .connectionTimeout):
            return true
        case (.invalidRedirectURI, .invalidRedirectURI):
            return true
        default:
            return false
        }
    }
}

@MainActor
class SpotifyService: NSObject, ObservableObject, SPTSessionManagerDelegate, SPTAppRemoteDelegate, SPTAppRemotePlayerStateDelegate {
    @Published private(set) var isConnected = false
    @Published var error: Error?
    @Published var isPlaying = false
    @Published var currentTrack: Track?
    @Published var authenticationError: Error?
    
    private var appRemote: SPTAppRemote?
    private var sessionManager: SPTSessionManager?
    private var accessToken: String?
    private var configuration: SPTConfiguration?
    private var connectionTimer: Timer?
    private var playbackQueue: [() -> Void] = []
    
    private var playerAPI: SPTAppRemotePlayerAPI? {
        return appRemote?.playerAPI
    }
    
    // Track played songs to prevent repetition
    private var playedSongs: Set<String> = []
    
    override init() {
        super.init()
        print("DEBUG: SpotifyService initialized")
        // Reset state on init
        isConnected = false
        error = nil
        authenticationError = nil
    }
    
    private func setupSpotifyIfNeeded() {
        print("DEBUG: Setting up Spotify")
        guard let redirectURL = URL(string: Configuration.spotifyRedirectURI) else {
            print("ERROR: Invalid redirect URI: \(Configuration.spotifyRedirectURI)")
            error = SpotifyError.invalidRedirectURI
            return
        }
        
        // Create configuration - only clientID and redirectURL
        let configuration = SPTConfiguration(
            clientID: Configuration.spotifyClientId,
            redirectURL: redirectURL
        )
        self.configuration = configuration
        
        print("DEBUG: Configuration created with:")
        print("DEBUG: ▶️ clientID → \(configuration.clientID)")
        print("DEBUG: ▶️ redirectURL → \(configuration.redirectURL.absoluteString)")
        
        // Clean up any existing instances
        sessionManager = nil
        appRemote = nil
        
        // Instantiate the one-and-only session manager immediately after configuration
        sessionManager = SPTSessionManager(configuration: configuration, delegate: self)
        print("DEBUG: Created sessionManager with redirect → \(redirectURL.absoluteString)")
        
        // Initialize app remote
        appRemote = SPTAppRemote(configuration: configuration, logLevel: .debug)
        appRemote?.delegate = self
        
        print("DEBUG: Spotify setup complete")
    }
    
    func connect() {
        print("DEBUG: Connect called")
        
        // Reset state
        error = nil
        authenticationError = nil
        
        setupSpotifyIfNeeded()
        
        print("DEBUG: Initiating Spotify session")
        let scope: SPTScope = [.appRemoteControl, .streaming]
        
        // First try to connect with existing access token
        if let accessToken = self.accessToken {
            print("DEBUG: Attempting to connect with existing access token")
            appRemote?.connectionParameters.accessToken = accessToken
            appRemote?.connect()
        } else {
            print("DEBUG: No access token, initiating new session with PKCE")
            guard let sessionManager = sessionManager else {
                print("ERROR: Session manager not initialized")
                return
            }
            
            // Get the redirect URL from our stored configuration
            guard let redirectURL = configuration?.redirectURL else {
                print("ERROR: Configuration not set")
                return
            }
            
            print("DEBUG: Using session manager with redirect URL → \(redirectURL.absoluteString)")
            
            // Use PKCE flow with clientOnly option
            sessionManager.initiateSession(
                with: scope,
                options: .clientOnly,
                campaign: "SongBattleLogin"
            )
        }
    }
    
    func disconnect() {
        print("DEBUG: Disconnect called")
        if appRemote?.isConnected == true {
            appRemote?.disconnect()
        }
        isConnected = false
        accessToken = nil
        authenticationError = nil
        cleanup()
    }
    
    private func cleanup() {
        print("DEBUG: Cleaning up Spotify resources")
        connectionTimer?.invalidate()
        connectionTimer = nil
        playbackQueue.removeAll()
        
        // Clean up instances
        appRemote = nil
        sessionManager = nil
        print("DEBUG: Spotify cleaned up")
    }
    
    func playRandomSong() {
        guard appRemote?.isConnected == true else {
            print("DEBUG: Not connected to Spotify, queueing playback for when connected")
            playbackQueue.append { [weak self] in
                self?.playRandomSong()
            }
            connect()
            return
        }
        
        // If we've played all available tracks, reset the played tracks set
        if playedSongs.count >= 100 {
            print("DEBUG: Reset played tracks")
            playedSongs.removeAll()
        }
        
        print("DEBUG: Fetching recommended playlists...")
        appRemote?.contentAPI?.fetchRecommendedContentItems(forType: "default", flattenContainers: true) { [weak self] (result: Any?, error: Error?) in
            guard let self = self else { return }
            
            if let error = error {
                print("DEBUG: Error fetching recommended content: \(error.localizedDescription)")
                self.error = SpotifyError.playbackError(error.localizedDescription)
                return
            }
            
            guard let items = result as? [SPTAppRemoteContentItem] else {
                print("DEBUG: No recommended items found or invalid type")
                return
            }
            
            // Filter for container items (playlists) only
            let playlists = items.filter { item in
                let isContainer = item.isContainer
                if !isContainer {
                    print("DEBUG: Skipping non-container item: \(item.title ?? "Unknown")")
                }
                return isContainer
            }
            
            print("DEBUG: Found \(playlists.count) playlists")
            
            // Get a random playlist from the filtered items
            guard let randomPlaylist = playlists.randomElement() else {
                print("DEBUG: No playlists available")
                return
            }
            
            print("DEBUG: Selected playlist: \(randomPlaylist.title ?? "Unknown")")
            
            // Fetch tracks from the selected playlist
            appRemote?.contentAPI?.fetchChildren(of: randomPlaylist) { [weak self] (result: Any?, error: Error?) in
                guard let self = self else { return }
                
                if let error = error {
                    print("DEBUG: Error fetching playlist tracks: \(error.localizedDescription)")
                    self.error = SpotifyError.playbackError(error.localizedDescription)
                    return
                }
                
                guard let tracks = result as? [SPTAppRemoteContentItem] else {
                    print("DEBUG: No tracks found in playlist or invalid type")
                    return
                }
                
                print("DEBUG: Found \(tracks.count) tracks in playlist")
                
                // Filter out non-track items and already played tracks
                let unplayedTracks = tracks.compactMap { track -> String? in
                    let uri = track.uri
                    
                    // Debug each track's URI
                    print("DEBUG: Checking track - Title: \(track.title ?? "Unknown"), URI: \(uri)")
                    
                    // Check if it's a track
                    if !uri.hasPrefix("spotify:track:") {
                        print("DEBUG: Skipping non-track URI: \(uri)")
                        return nil
                    }
                    
                    // Check if it's already played
                    if self.playedSongs.contains(uri) {
                        print("DEBUG: Skipping already played track: \(uri)")
                        return nil
                    }
                    
                    print("DEBUG: Found valid unplayed track: \(track.title ?? "Unknown") - \(uri)")
                    return uri
                }
                
                print("DEBUG: Found \(unplayedTracks.count) unplayed tracks")
                
                if unplayedTracks.isEmpty {
                    print("DEBUG: No unplayed tracks found in this playlist, trying another playlist")
                    self.playRandomSong() // Try again with a different playlist
                    return
                }
                
                // Select a random track from the unplayed tracks
                if let randomTrack = unplayedTracks.randomElement() {
                    print("DEBUG: Selected random track for playback: \(randomTrack)")
                    self.playedSongs.insert(randomTrack)
                    print("DEBUG: Added track to played songs, total played: \(self.playedSongs.count)")
                    self.playerAPI?.play(randomTrack)
                }
            }
        }
    }
    
    func play(_ trackUri: String) {
        guard appRemote?.isConnected == true else {
            error = SpotifyError.connectionFailed("Not connected to Spotify")
            return
        }
        
        playerAPI?.play(trackUri) { [weak self] (_, error: Error?) in
            Task { @MainActor in
                if let error = error {
                    self?.error = SpotifyError.playbackError(error.localizedDescription)
                }
            }
        }
    }
    
    func pause() {
        guard appRemote?.isConnected == true else { return }
        
        playerAPI?.pause { [weak self] (_, error: Error?) in
            Task { @MainActor in
                if let error = error {
                    self?.error = SpotifyError.playbackError(error.localizedDescription)
                }
            }
        }
    }
    
    func resume() {
        guard appRemote?.isConnected == true else { return }
        
        playerAPI?.resume { [weak self] (_, error: Error?) in
            Task { @MainActor in
                if let error = error {
                    self?.error = SpotifyError.playbackError(error.localizedDescription)
                }
            }
        }
    }
    
    func skipNext() {
        guard appRemote?.isConnected == true else { return }
        
        playerAPI?.skip(toNext: { [weak self] (_, error: Error?) in
            Task { @MainActor in
                if let error = error {
                    self?.error = SpotifyError.playbackError(error.localizedDescription)
                }
            }
        })
    }
    
    func skipPrevious() {
        guard appRemote?.isConnected == true else { return }
        
        playerAPI?.skip(toPrevious: { [weak self] (_, error: Error?) in
            Task { @MainActor in
                if let error = error {
                    self?.error = SpotifyError.playbackError(error.localizedDescription)
                }
            }
        })
    }
    
    // MARK: - URL Handling
    
    func handleURL(_ url: URL) -> Bool {
        print("DEBUG: Handling URL: \(url.absoluteString)")
        
        guard let sessionManager = sessionManager else {
            print("DEBUG: No session manager available")
            return false
        }
        
        let handled = sessionManager.application(UIApplication.shared, open: url, options: [:])
        print("DEBUG: ▶️ onOpenURL handled by sessionManager: \(handled)")
        
        if !handled {
            // If session manager didn't handle it, check if it's an error response
            if url.absoluteString.contains("error=") {
                print("DEBUG: URL contains error, parsing error details")
                if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                   let error = components.queryItems?.first(where: { $0.name == "error" })?.value,
                   let description = components.queryItems?.first(where: { $0.name == "error_description" })?.value {
                    print("DEBUG: Error: \(error)")
                    print("DEBUG: Description: \(description)")
                    Task { @MainActor in
                        self.error = SpotifyError.authenticationError(description)
                        self.authenticationError = SpotifyError.authenticationError(description)
                    }
                }
            }
        }
        
        return handled
    }
    
    // MARK: - SPTSessionManagerDelegate
    
    nonisolated func sessionManager(manager: SPTSessionManager, didInitiate session: SPTSession) {
        Task { @MainActor in
            print("DEBUG: Session initiated successfully")
            print("DEBUG: Access token: \(session.accessToken)")
            print("DEBUG: Expiration date: \(session.expirationDate)")
            
            self.accessToken = session.accessToken
            self.appRemote?.connectionParameters.accessToken = session.accessToken
            self.appRemote?.connect()
        }
    }
    
    nonisolated func sessionManager(manager: SPTSessionManager, didFailWith error: Error) {
        Task { @MainActor in
            print("ERROR: Failed to initialize session: \(error)")
            print("ERROR: Localized description: \(error.localizedDescription)")
            if let nsError = error as NSError? {
                print("ERROR: Domain: \(nsError.domain), Code: \(nsError.code)")
                print("ERROR: User info: \(nsError.userInfo)")
            }
            self.error = error
            self.authenticationError = error
        }
    }
    
    nonisolated func sessionManager(manager: SPTSessionManager, didRenew session: SPTSession) {
        Task { @MainActor in
            print("DEBUG: Session renewed successfully")
            print("DEBUG: New access token: \(session.accessToken)")
            print("DEBUG: New expiration date: \(session.expirationDate)")
            
            self.accessToken = session.accessToken
            self.appRemote?.connectionParameters.accessToken = session.accessToken
            // Don't need to reconnect here as the token was just renewed
        }
    }
    
    // MARK: - SPTAppRemoteDelegate
    
    nonisolated func appRemoteDidEstablishConnection(_ appRemote: SPTAppRemote) {
        Task { @MainActor in
            print("✅ AppRemote connected, now safe to fetch or play")
            self.isConnected = true
            self.error = nil
            
            // Set up player state subscription
            appRemote.playerAPI?.delegate = self
            appRemote.playerAPI?.subscribe(toPlayerState: { [weak self] success, error in
                if let error = error {
                    print("DEBUG: Failed to subscribe to player state:", error)
                    Task { @MainActor in
                        self?.error = SpotifyError.playbackError(error.localizedDescription)
                    }
                }
            })
            
            // Process any queued playback requests
            while !playbackQueue.isEmpty {
                playbackQueue.removeFirst()()
            }
        }
    }
    
    nonisolated func appRemote(_ appRemote: SPTAppRemote, didDisconnectWithError error: Error?) {
        Task { @MainActor in
            print("DEBUG: Disconnected from Spotify:", error?.localizedDescription ?? "no error")
            self.isConnected = false
            
            if let nsError = error as NSError?,
               nsError.domain == "com.spotify.app-remote.transport",
               nsError.code == -2001 {
                print("🔄 End of stream detected, reconnecting...")
                // Attempt to reconnect after a delay
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                self.connect()
            } else if let error = error {
                self.error = SpotifyError.connectionFailed(error.localizedDescription)
                self.authenticationError = error
            }
            
            cleanup()
        }
    }
    
    nonisolated func appRemote(_ appRemote: SPTAppRemote, didFailConnectionAttemptWithError error: Error?) {
        Task { @MainActor in
            print("DEBUG: Failed to connect to Spotify:", error?.localizedDescription ?? "unknown error")
            self.isConnected = false
            if let error = error {
                self.error = SpotifyError.connectionFailed(error.localizedDescription)
                self.authenticationError = error
            }
            cleanup()
        }
    }
    
    // MARK: - SPTAppRemotePlayerStateDelegate
    
    nonisolated func playerStateDidChange(_ playerState: SPTAppRemotePlayerState) {
        Task { @MainActor in
            updatePlayerState(playerState)
        }
    }
    
    private func updatePlayerState(_ playerState: SPTAppRemotePlayerState) {
        let newTrack = Track(
            id: playerState.track.uri,
            name: playerState.track.name,
            artist: playerState.track.artist.name,
            previewUrl: nil,
            albumArtUrl: nil
        )
        
        self.isPlaying = !playerState.isPaused
        self.currentTrack = newTrack
        
        // Fetch album art if available - use weak self to prevent retain cycles
        weak var weakSelf = self
        appRemote?.imageAPI?.fetchImage(forItem: playerState.track, with: CGSize(width: 64, height: 64)) { (image, error) in
            Task { @MainActor in
                guard let self = weakSelf else { return }
                
                if let error = error {
                    print("DEBUG: Error fetching album art: \(error)")
                } else if let image = image as? UIImage,
                          let currentTrack = self.currentTrack,
                          currentTrack.id == playerState.track.uri { // Only update if it's still the same track
                    self.currentTrack = Track(
                        id: currentTrack.id,
                        name: currentTrack.name,
                        artist: currentTrack.artist,
                        previewUrl: currentTrack.previewUrl,
                        albumArtUrl: image.pngData()?.base64EncodedString()
                    )
                }
            }
        }
    }
} 
