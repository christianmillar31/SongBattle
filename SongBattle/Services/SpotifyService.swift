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
    
    override init() {
        super.init()
        print("DEBUG: SpotifyService initialized")
        // Reset state on init
        isConnecting = false
        error = nil
        authenticationError = nil
        isConnected = false
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
        print("DEBUG: Connect called, isConnecting: \(isConnecting)")
        guard !isConnecting else { return }
        
        // Reset state
        error = nil
        authenticationError = nil
        isConnected = false
        connectionRetryCount = 0
        
        setupSpotifyIfNeeded()
        
        isConnecting = true
        
        // Start connection timeout timer
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
        error = SpotifyError.connectionTimeout
        isConnecting = false
        cleanup()
    }
    
    private func cleanup() {
        print("DEBUG: Cleaning up Spotify resources")
        connectionTimer?.invalidate()
        connectionTimer = nil
        
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
    
    func play(_ trackUri: String) {
        guard appRemote?.isConnected == true else {
            error = NSError(domain: "Spotify", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not connected to Spotify"])
            return
        }
        
        playerAPI?.play(trackUri, callback: { [weak self] _, error in
            Task { @MainActor in
                if let error = error {
                    self?.error = error
                }
            }
        })
    }
    
    func pause() {
        playerAPI?.pause({ [weak self] _, error in
            Task { @MainActor in
                if let error = error {
                    self?.error = error
                }
            }
        })
    }
    
    func resume() {
        playerAPI?.resume({ [weak self] _, error in
            Task { @MainActor in
                if let error = error {
                    self?.error = error
                }
            }
        })
    }
    
    func skipNext() {
        playerAPI?.skip(toNext: { [weak self] _, error in
            Task { @MainActor in
                if let error = error {
                    self?.error = error
                }
            }
        })
    }
    
    func skipPrevious() {
        playerAPI?.skip(toPrevious: { [weak self] _, error in
            Task { @MainActor in
                if let error = error {
                    self?.error = error
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
                }
            })
        }
    }
    
    nonisolated func appRemote(_ appRemote: SPTAppRemote, didFailConnectionAttemptWithError error: Error?) {
        Task { @MainActor in
            print("DEBUG: Failed to connect to Spotify:", error?.localizedDescription ?? "unknown error")
            
            if connectionRetryCount < maxConnectionRetries {
                connectionRetryCount += 1
                print("DEBUG: Retrying connection attempt \(connectionRetryCount)")
                self.connect()
            } else {
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
                self.error = SpotifyError.connectionFailed(error.localizedDescription)
                self.authenticationError = error
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
        
        // Fetch album art if available
        appRemote?.imageAPI?.fetchImage(forItem: playerState.track, with: CGSize(width: 64, height: 64)) { [weak self] (image, error) in
            Task { @MainActor in
                if let error = error {
                    print("Error fetching album art:", error)
                } else if let image = image as? UIImage {
                    self?.currentTrack = Track(
                        id: newTrack.id,
                        name: newTrack.name,
                        artist: newTrack.artist,
                        previewUrl: newTrack.previewUrl,
                        albumArtUrl: image.pngData()?.base64EncodedString()
                    )
                }
            }
        }
    }
} 
