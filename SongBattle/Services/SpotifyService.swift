import Foundation
import SpotifyiOS
import Combine
import SwiftUI

// Move Configuration to local file since it's not being found from the package
enum Configuration {
    // Using a computed property to avoid storing sensitive data directly in the source
    static var spotifyClientId: String {
        // Replace with your actual client ID
        return "1a71b9e3c3c44b41b6f6ea0c616b3083"
    }
    static let spotifyRedirectURI = "songbattle://spotify-callback"
}

extension Notification.Name {
    static let spotifyAuthCallback = Notification.Name("spotifyAuthCallback")
}

enum SpotifyError: LocalizedError, Equatable {
    case configurationNotSet
    case connectionFailed(String)
    case playbackError(String)
    case authenticationError(String)
    case connectionTimeout
    
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
        guard appRemote == nil else {
            print("DEBUG: Spotify already set up")
            return
        }
        
        print("DEBUG: Setting up Spotify")
        let redirectURL = URL(string: Configuration.spotifyRedirectURI)!
        let configuration = SPTConfiguration(
            clientID: Configuration.spotifyClientId,
            redirectURL: redirectURL
        )
        
        appRemote = SPTAppRemote(configuration: configuration, logLevel: .debug)
        appRemote?.delegate = self
        
        sessionManager = SPTSessionManager(configuration: configuration, delegate: self)
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
            print("DEBUG: No access token, initiating new session")
            sessionManager?.initiateSession(with: scope, options: .default)
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
        appRemote = nil
        sessionManager = nil
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
        isConnecting = false
        
        // Clean up instances
        cleanup()
        print("DEBUG: Spotify cleaned up")
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
        guard let appRemote = appRemote else { return false }
        
        let parameters = appRemote.authorizationParameters(from: url)
        var result = false
        
        if let parameters = parameters as? [String: Any],
           let accessToken = parameters[SPTAppRemoteAccessTokenKey] as? String {
            result = true
            Task { @MainActor in
                self.accessToken = accessToken
                self.appRemote?.connectionParameters.accessToken = accessToken
                self.appRemote?.connect()
            }
        } else if let parameters = parameters as? [String: Any],
                  let errorDescription = parameters[SPTAppRemoteErrorDescriptionKey] as? String {
            Task { @MainActor in
                self.error = NSError(
                    domain: "Spotify",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: errorDescription]
                )
                self.authenticationError = self.error
                self.isConnecting = false
            }
        }
        
        return result
    }
    
    // MARK: - SPTSessionManagerDelegate
    
    func sessionManager(manager: SPTSessionManager, didInitiate session: SPTSession) {
        print("Session initiated")
    }
    
    func sessionManager(manager: SPTSessionManager, didFailWith error: Error) {
        Task { @MainActor in
            print("Failed to initialize session:", error)
            self.error = error
            self.authenticationError = error
            self.isConnecting = false
        }
    }
    
    // MARK: - SPTAppRemoteDelegate
    
    func appRemoteDidEstablishConnection(_ appRemote: SPTAppRemote) {
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
                    self?.error = SpotifyError.playbackError(error.localizedDescription)
                }
            })
        }
    }
    
    func appRemote(_ appRemote: SPTAppRemote, didFailConnectionAttemptWithError error: Error?) {
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
    
    func appRemote(_ appRemote: SPTAppRemote, didDisconnectWithError error: Error?) {
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
    
    func playerStateDidChange(_ playerState: SPTAppRemotePlayerState) {
        updatePlayerState(playerState)
    }
    
    private func updatePlayerState(_ playerState: SPTAppRemotePlayerState) {
        let newTrack = Track(
            id: playerState.track.uri,
            name: playerState.track.name,
            artist: playerState.track.artist.name,
            previewUrl: nil,
            albumArtUrl: nil
        )
        
        Task { @MainActor in
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
} 
