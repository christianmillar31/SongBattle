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
    @Published var isConnecting = false
    @Published var error: Error?
    @Published var isPlaying = false
    @Published var currentTrack: Track?
    @Published var isConnected = false
    @Published var authenticationError: Error?
    
    private var appRemote: SPTAppRemote?
    private var sessionManager: SPTSessionManager?
    private var accessToken: String?
    private var configuration: SPTConfiguration?
    private var playerAPI: SPTAppRemotePlayerAPI? {
        return appRemote?.playerAPI
    }
    
    private var connectionRetryCount = 0
    private let maxConnectionRetries = 3
    private var connectionTimer: Timer?
    private var lastConnectionAttempt: Date?
    private let minimumConnectionInterval: TimeInterval = 2.0 // Minimum time between connection attempts
    private let maxBackoffInterval: TimeInterval = 60.0 // Maximum backoff time in seconds
    
    // Track played songs to prevent repetition
    private var playedSongs: Set<String> = []
    
    // Add property to track play attempts
    private var playAttempt = 0
    private let maxPlayAttempts = 3
    private let trackType = SPTAppRemoteRecommendedContentType.tracks
    
    override init() {
        super.init()
        print("DEBUG: SpotifyService initialized")
        // Reset state on init
        isConnecting = false
        error = nil
        authenticationError = nil
        isConnected = false
    }
    
    private func calculateBackoffInterval() -> TimeInterval {
        // Exponential backoff: 2^n seconds, where n is the retry count
        let interval = pow(2.0, Double(connectionRetryCount))
        // Cap at maxBackoffInterval
        return min(interval, maxBackoffInterval)
    }
    
    private func retryConnection() {
        guard connectionRetryCount < maxConnectionRetries else {
            print("DEBUG: Max retries reached, giving up")
            isConnecting = false
            error = SpotifyError.connectionFailed("Max retries reached")
            return
        }
        
        connectionRetryCount += 1
        let backoffInterval = calculateBackoffInterval()
        print("DEBUG: Retrying connection in \(backoffInterval) seconds (attempt \(connectionRetryCount))")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + backoffInterval) { [weak self] in
            self?.connect()
        }
    }
    
    private func handleConnectionFailure(_ error: Error?) {
        print("DEBUG: Connection failed with error: \(String(describing: error))")
        self.error = error
        retryConnection()
    }
    
    private func setupSpotifyIfNeeded() {
        print("DEBUG: Setting up Spotify")
        guard let redirectURL = URL(string: Configuration.spotifyRedirectURI) else {
            print("ERROR: Invalid redirect URI: \(Configuration.spotifyRedirectURI)")
            error = SpotifyError.invalidRedirectURI
            return
        }
        
        // Check if Spotify is installed
        guard let spotifyURL = URL(string: "spotify:") else { return }
        if !UIApplication.shared.canOpenURL(spotifyURL) {
            print("ERROR: Spotify app is not installed")
            error = SpotifyError.connectionFailed("Spotify app is not installed. Please install Spotify from the App Store.")
            isConnecting = false
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
    
    private func openSpotify() {
        guard let spotifyURL = URL(string: "spotify:") else { return }
        UIApplication.shared.open(spotifyURL) { success in
            if success {
                print("DEBUG: Opened Spotify app")
                // Wait a moment for Spotify to launch before retrying connection
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                    self?.connect()
                }
            } else {
                print("ERROR: Failed to open Spotify app")
                self.error = SpotifyError.connectionFailed("Failed to open Spotify app")
            }
        }
    }
    
    func connect() {
        print("DEBUG: Connect called, isConnecting: \(isConnecting)")
        
        // Check if we're already connecting
        guard !isConnecting else {
            print("DEBUG: Already attempting to connect, skipping")
            return
        }
        
        // Rate limit connection attempts
        if let lastAttempt = lastConnectionAttempt {
            let timeSinceLastAttempt = Date().timeIntervalSince(lastAttempt)
            if timeSinceLastAttempt < minimumConnectionInterval {
                print("DEBUG: Connection attempt too soon, waiting...")
                DispatchQueue.main.asyncAfter(deadline: .now() + (minimumConnectionInterval - timeSinceLastAttempt)) { [weak self] in
                    self?.connect()
                }
                return
            }
        }
        
        // Reset state
        error = nil
        authenticationError = nil
        isConnected = false
        connectionRetryCount = 0
        lastConnectionAttempt = Date()
        
        setupSpotifyIfNeeded()
        
        isConnecting = true
        
        // Start connection timeout timer
        connectionTimer?.invalidate()
        connectionTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.handleConnectionTimeout()
            }
        }
        
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
    
    private func handleConnectionTimeout() {
        guard isConnecting else { return }
        print("DEBUG: Connection attempt timed out")
        error = SpotifyError.connectionTimeout
        isConnecting = false
        cleanup()
        
        // Schedule a retry if within retry limits
        if connectionRetryCount < maxConnectionRetries {
            connectionRetryCount += 1
            print("DEBUG: Scheduling retry attempt \(connectionRetryCount) after timeout")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.connect()
            }
        }
    }
    
    private func cleanup() {
        print("DEBUG: Cleaning up Spotify resources")
        connectionTimer?.invalidate()
        connectionTimer = nil
        
        // Unsubscribe from player state to prevent memory leaks
        appRemote?.playerAPI?.unsubscribe(toPlayerState: { _, error in
            if let error = error {
                print("⚠️ Cleanup: Failed to unsubscribe from player state: \(error.localizedDescription)")
            }
        })
        
        // Only clean up if we're not in the middle of connecting
        if !isConnecting {
            print("DEBUG: Fully cleaning up Spotify instances")
            appRemote = nil
            sessionManager = nil
        } else {
            print("DEBUG: Keeping Spotify instances for auth callback")
        }
    }
    
    func disconnect() {
        print("DEBUG: Disconnect called")
        connectionTimer?.invalidate()
        connectionTimer = nil
        
        // Unsubscribe and disconnect
        appRemote?.playerAPI?.unsubscribe(toPlayerState: { _, error in
            if let error = error {
                print("⚠️ Disconnect: Failed to unsubscribe from player state: \(error.localizedDescription)")
            }
        })
        if appRemote?.isConnected == true {
            appRemote?.disconnect()
        }
        
        isConnected = false
        accessToken = nil
        authenticationError = nil
        
        // Only reset connecting state if we're not in the middle of auth
        if !isConnecting {
            isConnecting = false
            // Clean up instances
            cleanup()
            print("DEBUG: Spotify cleaned up")
        } else {
            print("DEBUG: Keeping connection state for auth callback")
        }
    }
    
    // MARK: - Playback Control
    
    private func handleConnectionError(_ error: Error) {
        print("DEBUG: Connection error: \(error.localizedDescription)")
        
        let nsError = error as NSError
        if nsError.domain == "com.spotify.app-remote.transport" {
            switch nsError.code {
            case -2001:
                // End of stream: ok to reconnect after delay
                print("DEBUG: End of stream detected, attempting to reconnect after delay...")
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                    self?.connect()
                }
            default:
                // Other transport errors: let didFailConnectionAttemptWithError handle retries
                print("DEBUG: Transport error, letting retry logic handle reconnection")
                return
            }
        } else if nsError.domain == "com.spotify.app-remote.wamp-client" && nsError.code == -3000 {
            // Content API error (not a container) - ignore and continue
            print("DEBUG: Ignoring content API error (not a container)")
            return
        } else {
            // For other errors, try to reconnect through normal retry logic
            print("DEBUG: Non-transport error, attempting normal retry")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.connect()
            }
        }
    }
    
    func playRandomSong() {
        // Increment and check attempt counter
        playAttempt += 1
        guard playAttempt <= maxPlayAttempts else {
            print("DEBUG: 💥 Giving up after \(maxPlayAttempts) attempts")
            error = SpotifyError.playbackError("Failed to find tracks after \(maxPlayAttempts) attempts")
            playAttempt = 0  // Reset for next time
            return
        }
        
        guard let appRemote = appRemote else {
            print("DEBUG: AppRemote not initialized")
            connect()
            return
        }
        
        if !appRemote.isConnected {
            print("DEBUG: Not connected to Spotify, attempting to connect...")
            connect()
            return
        }
        
        // If we've played all available tracks, reset the played tracks set
        if playedSongs.count >= 100 {
            print("DEBUG: Reset played tracks")
            playedSongs.removeAll()
        }
        
        print("DEBUG: Fetching recommended tracks (attempt \(playAttempt)/\(maxPlayAttempts))...")
        
        // Use tracks content type specifically with proper type annotation
        appRemote.contentAPI?.fetchRecommendedContentItems(
            forType: trackType,
            flattenContainers: true
        ) { [weak self] (result: Any?, error: Error?) in
            guard let self = self else { return }
            
            if let error = error {
                print("DEBUG: Error fetching recommended content: \(error.localizedDescription)")
                // Handle end of stream specifically
                if let nsError = error as NSError?,
                   nsError.domain == "com.spotify.app-remote.transport",
                   nsError.code == -2001 {
                    print("DEBUG: End of stream detected, reconnecting...")
                    self.connect()
                } else {
                    self.handleConnectionError(error)
                }
                return
            }
            
            guard let items = result as? [SPTAppRemoteContentItem],
                  !items.isEmpty else {
                print("DEBUG: ⚠️ No tracks found - retrying (attempt \(self.playAttempt))")
                self.playRandomSong()
                return
            }
            
            // Reset attempt counter since we found items
            self.playAttempt = 0
            
            // Get track URIs with enhanced filtering
            let trackURIs = items.compactMap { item -> String? in
                // Skip non-track content types
                guard item.contentType == "track" else {
                    print("DEBUG: Skipping non-track content: \(item.contentType ?? "unknown type")")
                    return nil
                }
                
                let uri = item.uri
                
                // Verify it's a valid track URI
                guard uri.hasPrefix("spotify:track:") else {
                    print("DEBUG: Skipping invalid track URI format: \(uri)")
                    return nil
                }
                
                // Skip if already played
                guard !self.playedSongs.contains(uri) else {
                    print("DEBUG: Skipping already played track: \(item.title ?? "Unknown")")
                    return nil
                }
                
                print("DEBUG: Found valid track: \(item.title ?? "Unknown") - \(uri)")
                return uri
            }
            
            print("DEBUG: Found \(trackURIs.count) unplayed tracks")
            
            if let randomTrack = trackURIs.randomElement() {
                print("DEBUG: Selected random track for playback: \(randomTrack)")
                self.playedSongs.insert(randomTrack)
                print("DEBUG: Added track to played songs, total played: \(self.playedSongs.count)")
                
                // Add callback to handle playback errors
                appRemote.playerAPI?.play(randomTrack) { [weak self] (_, error: Error?) in
                    if let error = error {
                        print("DEBUG: Playback error: \(error.localizedDescription)")
                        self?.handleConnectionError(error)
                    } else {
                        print("DEBUG: ▶️ Now playing \(randomTrack)")
                    }
                }
            } else if self.playAttempt < self.maxPlayAttempts {
                // If we filtered out all tracks (because they were played), try again
                print("DEBUG: All tracks were already played, retrying...")
                self.playRandomSong()
            } else {
                print("DEBUG: 💥 Failed to find any unplayed tracks after \(self.maxPlayAttempts) attempts")
                self.error = SpotifyError.playbackError("No unplayed tracks available")
                self.playAttempt = 0  // Reset for next time
            }
        }
    }
    
    func play(_ trackUri: String) {
        guard appRemote?.isConnected == true else {
            error = SpotifyError.connectionFailed("Not connected to Spotify")
            return
        }
        
        playerAPI?.play(trackUri) { [weak self] (_, error) in
            Task { @MainActor in
                if let error = error {
                    self?.error = SpotifyError.playbackError(error.localizedDescription)
                }
            }
        }
    }
    
    func pause() {
        guard appRemote?.isConnected == true else { return }
        
        playerAPI?.pause { [weak self] (_, error) in
            Task { @MainActor in
                if let error = error {
                    self?.error = SpotifyError.playbackError(error.localizedDescription)
                }
            }
        }
    }
    
    func resume() {
        guard appRemote?.isConnected == true else { return }
        
        playerAPI?.resume { [weak self] (_, error) in
            Task { @MainActor in
                if let error = error {
                    self?.error = SpotifyError.playbackError(error.localizedDescription)
                }
            }
        }
    }
    
    func skipNext() {
        guard appRemote?.isConnected == true else { return }
        
        playerAPI?.skip(toNext: { [weak self] (_, error) in
            Task { @MainActor in
                if let error = error {
                    self?.error = SpotifyError.playbackError(error.localizedDescription)
                }
            }
        })
    }
    
    func skipPrevious() {
        guard appRemote?.isConnected == true else { return }
        
        playerAPI?.skip(toPrevious: { [weak self] (_, error) in
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
                        self.isConnecting = false
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
            self.isConnecting = false
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
            print("DEBUG: Connected to Spotify")
            connectionTimer?.invalidate()
            self.isConnected = true
            self.isConnecting = false
            self.error = nil
            
            // Set up player state subscription
        appRemote.playerAPI?.delegate = self
            appRemote.playerAPI?.subscribe(toPlayerState: { [weak self] success, error in
            if let error = error {
                    print("DEBUG: Failed to subscribe to player state:", error)
                    Task { @MainActor in
                        self?.error = SpotifyError.playbackError(error.localizedDescription)
                    }
                } else {
                    print("DEBUG: Successfully subscribed to player state")
                }
            })
            
            // If we were waiting to play a song, do it now
            if self.currentTrack == nil {
                print("DEBUG: No current track, ready to play")
            }
        }
    }
    
    nonisolated func appRemote(_ appRemote: SPTAppRemote, didFailConnectionAttemptWithError error: Error?) {
        Task { @MainActor in
            print("DEBUG: Failed to connect to Spotify:", error?.localizedDescription ?? "unknown error")
            
            // Check if the error is due to Spotify not running
            if let nsError = error as NSError?,
               nsError.domain == "com.spotify.app-remote.transport",
               nsError.code == -2000 {
                print("DEBUG: Spotify app not running, attempting to open it")
                openSpotify()
                return
            }
            
            if connectionRetryCount < maxConnectionRetries {
                connectionRetryCount += 1
                print("DEBUG: Retrying connection attempt \(connectionRetryCount)")
                // Add delay before retry
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                self.connect()
            } else {
                print("DEBUG: Max retry attempts reached, stopping reconnection")
                self.isConnected = false
                if let error = error {
                    self.error = SpotifyError.connectionFailed(error.localizedDescription)
                    self.authenticationError = error
                }
                self.isConnecting = false
                cleanup()
            }
        }
    }
    
    nonisolated func appRemote(_ appRemote: SPTAppRemote, didDisconnectWithError error: Error?) {
        Task { @MainActor in
            print("DEBUG: Disconnected from Spotify:", error?.localizedDescription ?? "no error")
            self.isConnected = false
            if let error = error {
                // Handle end of stream specifically
                if let nsError = error as NSError?,
                   nsError.domain == "com.spotify.app-remote.transport",
                   nsError.code == -2001 {
                    print("DEBUG: End of stream detected during disconnect, attempting to reconnect...")
                    self.connect()
                } else {
                    self.error = SpotifyError.connectionFailed(error.localizedDescription)
                    self.authenticationError = error
                }
            }
            self.isConnecting = false
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
    
    func selectRandomSong() -> Track {
        return Track(
            id: UUID().uuidString,
            name: "Sample Song",  // Changed from title to name
            artist: "Sample Artist",
            previewUrl: "spotify:track:sample",  // Changed from uri to previewUrl
            albumArtUrl: nil
        )
    }
} 
