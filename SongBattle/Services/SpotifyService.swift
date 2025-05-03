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
    case notConnected
    case searchFailed
    case playbackFailed
    
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
        case .notConnected:
            return "Not connected to Spotify"
        case .searchFailed:
            return "Search failed"
        case .playbackFailed:
            return "Playback failed"
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
        case (.notConnected, .notConnected):
            return true
        case (.searchFailed, .searchFailed):
            return true
        case (.playbackFailed, .playbackFailed):
            return true
        default:
            return false
        }
    }
}

@MainActor
class SpotifyService: NSObject, ObservableObject, SPTSessionManagerDelegate, SPTAppRemoteDelegate, SPTAppRemotePlayerStateDelegate {
    static let shared = SpotifyService()
    
    // MARK: - Constants
    private let clientID = "c4788e07ffa548f78f8101af9c8aa0c5"
    private let redirectURL = URL(string: "songbattle://spotify-callback")!
    private let trackType = "default-tracks"  // Spotify's content type for recommended tracks
    
    @Published var isConnecting = false
    @Published var error: Error?
    @Published var isPlaying = false
    @Published var currentTrack: Track?
    @Published var isConnected = false
    @Published var authenticationError: Error?
    
    private var appRemote: SPTAppRemote?
    private var sessionManager: SPTSessionManager?
    private var accessToken: String? {
        didSet {
            if let token = accessToken {
                UserDefaults.standard.set(token, forKey: "spotify_access_token")
            } else {
                UserDefaults.standard.removeObject(forKey: "spotify_access_token")
            }
        }
    }
    private var configuration: SPTConfiguration?
    private var isInAuthFlow = false
    
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
    
    private var playerState: SPTAppRemotePlayerState?
    private var cancellables = Set<AnyCancellable>()
    private var categoryCache: [String: [Track]] = [:]
    private var lastFetchTime: [String: Date] = [:]
    private let cacheDuration: TimeInterval = 3600 // 1 hour
    
    private override init() {
        super.init()
        print("DEBUG: ⚠️ SpotifyService singleton initialized")
        setupSpotifyIfNeeded()
        
        // Add scene phase observation
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScenePhaseChange),
            name: UIScene.didActivateNotification,
            object: nil
        )
    }
    
    @objc private func handleScenePhaseChange() {
        print("DEBUG: Scene activated, checking connection status")
        if !isConnected && !isInAuthFlow && accessToken != nil {
            print("DEBUG: Have token but not connected, attempting to reconnect")
            connect()
        }
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
        print("DEBUG: 🔄 Setting up Spotify")
        
        guard let redirectURL = URL(string: Configuration.spotifyRedirectURI) else {
            print("ERROR: ❌ Invalid redirect URI: \(Configuration.spotifyRedirectURI)")
            error = SpotifyError.invalidRedirectURI
            return
        }
        
        // Only create configuration if needed
        if configuration == nil {
            configuration = SPTConfiguration(
            clientID: Configuration.spotifyClientId,
            redirectURL: redirectURL
        )
            print("DEBUG: 📝 Configuration created:")
            print("DEBUG: ▶️ clientID → \(configuration?.clientID ?? "nil")")
            print("DEBUG: ▶️ redirectURL → \(configuration?.redirectURL.absoluteString ?? "nil")")
        }
        
        // Create session manager if needed
        if sessionManager == nil {
            print("DEBUG: 🔑 Creating new session manager")
            sessionManager = SPTSessionManager(configuration: configuration!, delegate: self)
        }
        
        // Create app remote if needed
        if appRemote == nil {
            print("DEBUG: 📱 Creating new app remote")
            appRemote = SPTAppRemote(configuration: configuration!, logLevel: .debug)
        appRemote?.delegate = self
        }
        
        // Try to restore the access token
        if let storedToken = UserDefaults.standard.string(forKey: "spotify_access_token") {
            print("DEBUG: 🔄 Restored access token from UserDefaults")
            accessToken = storedToken
            appRemote?.connectionParameters.accessToken = storedToken
        }
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
        print("DEBUG: 🔌 Connect called, isConnecting: \(isConnecting), isInAuthFlow: \(isInAuthFlow)")
        
        guard !isConnecting else {
            print("DEBUG: ⚠️ Already attempting to connect, skipping")
            return
        }
        
        // Check if Spotify app is installed
        guard UIApplication.shared.canOpenURL(URL(string: "spotify:")!) else {
            print("DEBUG: ❌ Spotify app not installed")
            self.error = SpotifyError.connectionFailed("Spotify app not installed")
            return
        }
        
        isConnecting = true
        
        // Always clear stored token if we have an auth error
        if let currentError = error as NSError?,
           (currentError.domain == "com.spotify.app-remote.wamp-client" && currentError.code == -1001) ||
           (currentError.domain == "com.spotify.app-remote" && currentError.code == -1000) {
            print("DEBUG: 🔄 Clearing invalid token")
            accessToken = nil
            UserDefaults.standard.removeObject(forKey: "spotify_access_token")
            self.error = nil
            appRemote?.disconnect()
            cleanup()
        }
        
        // Reset connection state
        isConnected = false
        connectionRetryCount = 0
        
        if accessToken == nil {
            print("DEBUG: 🔑 No access token, initiating new session with PKCE")
            isInAuthFlow = true
            let scope: SPTScope = [.appRemoteControl, .streaming, .userReadEmail, .playlistReadPrivate, .userLibraryRead, .userTopRead]
            sessionManager?.initiateSession(with: scope, options: .clientOnly, campaign: "songsmash_login")
        } else {
            print("DEBUG: 🎵 Have access token, connecting app remote")
            appRemote?.connect()
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
        if !isInAuthFlow {
            print("DEBUG: Fully cleaning up Spotify instances")
            appRemote = nil
            setupSpotifyIfNeeded() // Recreate clean instances
            print("DEBUG: Spotify cleaned up")
        } else {
            print("DEBUG: In auth flow, keeping instances")
        }
    }
    
    func disconnect() {
        print("DEBUG: Disconnect called")
        // Don't disconnect if we're in auth flow or if we're just backgrounded
        guard !isInAuthFlow && UIApplication.shared.applicationState != .background else {
            print("DEBUG: Skipping disconnect - in auth flow or backgrounded")
            return
        }
        
        appRemote?.disconnect()
        isConnected = false
        cleanup()
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
    
    func playRandomSong(from categories: Set<MusicCategory> = []) {
        Task {
            do {
                let track = try await getRandomTrack(from: categories)
                if let track = track {
                    await play(track: track)
                }
            } catch {
                self.error = error
                print("Error playing random song: \(error)")
            }
        }
    }
    
    private func getRandomTrack(from categories: Set<MusicCategory>) async throws -> Track? {
        // If no categories selected, play any random song
        if categories.isEmpty {
            return try await getAnyRandomTrack()
        }
        
        // Get tracks for each category
        var allTracks: [Track] = []
        for category in categories {
            if let tracks = try await getTracksForCategory(category) {
                allTracks.append(contentsOf: tracks)
            }
        }
        
        // Remove duplicates (same track might match multiple categories)
        allTracks = Array(Set(allTracks))
        
        // Return random track if available
        return allTracks.randomElement()
    }
    
    func getTracksForCategory(_ category: MusicCategory, difficulty: String? = nil) async throws -> [Track]? {
        let cacheKey = category.id + (difficulty ?? "")
        // Check cache first
        if let cachedTracks = categoryCache[cacheKey],
           let lastFetch = lastFetchTime[cacheKey],
           Date().timeIntervalSince(lastFetch) < cacheDuration {
            return cachedTracks
        }
        // Build search parameters
        var genre: String? = nil
        var year: String? = nil
        switch category.type {
        case .genre:
            genre = category.id
        case .decade:
            // Convert decade to year range (e.g., "1960s" -> "1960-1969")
            let startYear = Int(category.id.prefix(4)) ?? 2020
            year = "\(startYear)-\(startYear + 9)"
        }
        // Map difficulty to popularity
        var minPopularity: Int? = nil
        var maxPopularity: Int? = nil
        if let difficulty = difficulty?.lowercased() {
            switch difficulty {
            case "easy":
                minPopularity = 60
                maxPopularity = 100
            case "medium":
                minPopularity = 30
                maxPopularity = 59
            case "hard":
                minPopularity = 0
                maxPopularity = 29
            default:
                break
            }
        }
        print("DEBUG: Fetching tracks for category: \(category.id), genre: \(genre ?? "nil"), year: \(year ?? "nil"), difficulty: \(difficulty ?? "nil")")
        // Fetch tracks from Spotify Web API
        let tracks = try await searchTracksWebAPI(query: "", genre: genre, year: year, minPopularity: minPopularity, maxPopularity: maxPopularity, limit: 20)
        // Update cache
        categoryCache[cacheKey] = tracks
        lastFetchTime[cacheKey] = Date()
        return tracks
    }
    
    private func getAnyRandomTrack() async throws -> Track? {
        // Use a generic search for popular songs
        let tracks = try await searchTracks(query: "tag:popular")
        return tracks.randomElement()
    }
    
    private func searchTracks(query: String) async throws -> [Track] {
        guard let appRemote = appRemote, appRemote.isConnected else {
            throw SpotifyError.notConnected
        }

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[Track], Error>) in
            // If query contains a genre or category, use search
            if query.contains("genre:") || query.contains("year:") {
                print("DEBUG: Using search for category-based query: \(query)")
                appRemote.contentAPI?.fetchRecommendedContentItems(forType: "search", flattenContainers: true) { (result: Any?, error: Error?) in
                    if let error = error {
                        print("DEBUG: Error fetching search results: \(error)")
                        continuation.resume(throwing: SpotifyError.searchFailed)
                        return
                    }

                    guard let items = result as? [SPTAppRemoteTrack] else {
                        print("DEBUG: Invalid search results type")
                        continuation.resume(throwing: SpotifyError.searchFailed)
                        return
                    }

                    let tracks = items.compactMap { track -> Track? in
                        guard !track.isPodcast && !track.isEpisode && !track.isAdvertisement else {
                            print("DEBUG: Skipping non-music content")
                            return nil
                        }

                        return Track(
                            id: track.uri,
                            name: track.name,
                            artist: track.artist.name,
                            uri: track.uri,
                            previewUrl: nil,
                            albumArtUrl: nil
                        )
                    }

                    if tracks.isEmpty {
                        print("DEBUG: No valid tracks found in search results")
                        continuation.resume(throwing: SpotifyError.searchFailed)
                    } else {
                        print("DEBUG: Successfully found \(tracks.count) tracks from search")
                        continuation.resume(returning: tracks)
                    }
                }
            } else {
                // For general random songs, use a curated playlist
                print("DEBUG: Using playlist for general random songs")
                // Step 1: Fetch root playlists
                appRemote.contentAPI?.fetchRecommendedContentItems(forType: "default", flattenContainers: false) { (result: Any?, error: Error?) in
                    if let error = error {
                        print("DEBUG: Error fetching root playlists: \(error)")
                        continuation.resume(throwing: SpotifyError.searchFailed)
                        return
                    }
                    guard let items = result as? [SPTAppRemoteContentItem] else {
                        print("DEBUG: Invalid result type from fetchRecommendedContentItems")
                        continuation.resume(throwing: SpotifyError.searchFailed)
                        return
                    }
                    // Step 2: Find 'Today's Top Hits' playlist
                    guard let playlistItem = items.first(where: { $0.title == "Today's Top Hits" }) else {
                        print("DEBUG: Could not find 'Today's Top Hits' playlist in root items")
                        continuation.resume(throwing: SpotifyError.searchFailed)
                        return
                    }
                    // Step 3: Fetch tracks from the playlist
                    appRemote.contentAPI?.fetchChildren(of: playlistItem, callback: { (result: Any?, error: Error?) in
                        if let error = error {
                            print("DEBUG: Error fetching playlist tracks: \(error)")
                            continuation.resume(throwing: SpotifyError.searchFailed)
                            return
                        }
                        guard let trackItems = result as? [SPTAppRemoteTrack] else {
                            print("DEBUG: Invalid tracks array type")
                            continuation.resume(throwing: SpotifyError.searchFailed)
                            return
                        }
                        let tracks = trackItems.compactMap { track -> Track? in
                            guard !track.isPodcast && !track.isEpisode && !track.isAdvertisement else {
                                print("DEBUG: Skipping non-music content")
                                return nil
                            }
                            return Track(
                                id: track.uri,
                                name: track.name,
                                artist: track.artist.name,
                                uri: track.uri,
                                previewUrl: nil,
                                albumArtUrl: nil
                            )
                        }
                        if tracks.isEmpty {
                            print("DEBUG: No valid tracks found in playlist")
                            continuation.resume(throwing: SpotifyError.searchFailed)
                        } else {
                            print("DEBUG: Successfully found \(tracks.count) tracks from playlist")
                            continuation.resume(returning: tracks)
                        }
                    })
                }
            }
        }
    }
    
    func play(track: Track) async {
        guard let appRemote = appRemote, appRemote.isConnected else { return }
        
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            appRemote.playerAPI?.play(track.uri) { [weak self] (_, error: Error?) in
                if let error = error {
                    self?.error = error
                    print("Error playing track: \(error)")
                } else {
                    self?.currentTrack = track
                    self?.isPlaying = true
                }
                continuation.resume()
            }
        }
    }
    
    func pause() {
        guard let appRemote = appRemote, appRemote.isConnected else { return }
        appRemote.playerAPI?.pause { [weak self] (_, error: Error?) in
                if let error = error {
                self?.error = error
            } else {
                self?.isPlaying = false
            }
        }
    }
    
    func resume() {
        guard let appRemote = appRemote, appRemote.isConnected else { return }
        appRemote.playerAPI?.resume { [weak self] (_, error: Error?) in
                if let error = error {
                self?.error = error
            } else {
                self?.isPlaying = true
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
        print("DEBUG: 🔗 Handling URL: \(url)")
        
        // Don't recreate session manager, just ensure we have one
        if sessionManager == nil {
            print("DEBUG: ⚠️ No session manager available during URL handling, creating one")
            setupSpotifyIfNeeded()
        }
        
        guard let sessionManager = sessionManager else {
            print("DEBUG: ❌ Failed to create session manager for URL handling")
            return false
        }
        
        let handled = sessionManager.application(UIApplication.shared, open: url, options: [:])
        print("DEBUG: 📲 URL handling result: \(handled ? "success" : "failure")")
        return handled
    }
    
    // MARK: - SPTSessionManagerDelegate
    
    nonisolated func sessionManager(manager: SPTSessionManager, didInitiate session: SPTSession) {
        Task { @MainActor in
            print("DEBUG: ✅ Session initiated successfully")
            print("DEBUG: 📝 Access token received: \(session.accessToken.prefix(10))...")
            isInAuthFlow = false
            isConnecting = false
            accessToken = session.accessToken
            appRemote?.connectionParameters.accessToken = session.accessToken
            
            // Ensure we're not in background before connecting
            if UIApplication.shared.applicationState != .background {
                print("DEBUG: 🎵 Connecting app remote after successful auth")
                appRemote?.connect()
            } else {
                print("DEBUG: ⏸ App in background, deferring app remote connection")
            }
        }
    }
    
    nonisolated func sessionManager(manager: SPTSessionManager, didFailWith error: Error) {
        Task { @MainActor in
            print("DEBUG: ❌ Session initiation failed: \(error)")
            print("DEBUG: 🔍 Error details - Domain: \((error as NSError).domain), Code: \((error as NSError).code)")
            isInAuthFlow = false
            isConnecting = false
            authenticationError = error
            
            // Don't reset everything on failure, just clear the failing token
            accessToken = nil
            UserDefaults.standard.removeObject(forKey: "spotify_access_token")
        }
    }
    
    // MARK: - SPTAppRemoteDelegate
    
    nonisolated func appRemoteDidEstablishConnection(_ appRemote: SPTAppRemote) {
        Task { @MainActor in
            print("DEBUG: App remote connection established")
            appRemote.playerAPI?.delegate = self
            appRemote.playerAPI?.subscribe { [weak self] (_, error) in
                Task { @MainActor in
                    if let error = error {
                        print("DEBUG: Error subscribing to player state: \(error)")
                    } else {
                        print("DEBUG: Successfully subscribed to player state")
                        self?.isConnected = true
                        self?.isConnecting = false
                    }
                }
            }
        }
    }
    
    nonisolated func appRemote(_ appRemote: SPTAppRemote, didDisconnectWithError error: Error?) {
        Task { @MainActor in
            print("DEBUG: App remote disconnected with error: \(String(describing: error))")
            isConnected = false
                if let error = error {
                self.error = error
            }
        }
    }
    
    nonisolated func appRemote(_ appRemote: SPTAppRemote, didFailConnectionAttemptWithError error: Error?) {
        Task { @MainActor in
            print("DEBUG: App remote connection attempt failed: \(String(describing: error))")
            isConnecting = false
            
            if let error = error as NSError? {
                self.error = error
                
                // Check if it's an auth error
                if error.domain == "com.spotify.app-remote.wamp-client" && error.code == -1001 {
                    print("DEBUG: Auth error detected, initiating new auth flow")
                    accessToken = nil
                    UserDefaults.standard.removeObject(forKey: "spotify_access_token")
                    isInAuthFlow = true
                    let scope: SPTScope = [.appRemoteControl, .streaming, .userReadEmail, .playlistReadPrivate, .userLibraryRead, .userTopRead]
                    sessionManager?.initiateSession(with: scope, options: .clientOnly, campaign: "songsmash_login")
                } else if connectionRetryCount < maxConnectionRetries {
                    // For other errors, try reconnecting
                    connectionRetryCount += 1
                    print("DEBUG: Retrying connection (attempt \(connectionRetryCount))")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        self.connect()
                    }
                } else {
                    print("DEBUG: Max retries reached")
                    cleanup()
                }
            }
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
            uri: playerState.track.uri,
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
                        uri: currentTrack.uri,
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
            name: "Sample Song",
            artist: "Sample Artist",
            uri: "spotify:track:sample",
            previewUrl: nil,
            albumArtUrl: nil
        )
    }
    
    /// Search tracks using the Spotify Web API with support for genre, decade, and difficulty (popularity)
    func searchTracksWebAPI(query: String = "", genre: String? = nil, year: String? = nil, minPopularity: Int? = nil, maxPopularity: Int? = nil, limit: Int = 20) async throws -> [Track] {
        guard let accessToken = self.accessToken else {
            throw SpotifyError.authenticationError("No access token")
        }
        var urlString = "https://api.spotify.com/v1/search?q="
        var queryItems: [String] = []
        if let genre = genre, !genre.isEmpty {
            queryItems.append("genre:\"\(genre)\"")
        }
        if let year = year, !year.isEmpty {
            queryItems.append("year:\(year)")
        }
        if !query.isEmpty {
            queryItems.append(query)
        }
        urlString += queryItems.joined(separator: " ")
        urlString += "&type=track&limit=\(limit)"
        guard let url = URL(string: urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!) else {
            throw SpotifyError.searchFailed
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw SpotifyError.searchFailed
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let tracksDict = json?["tracks"] as? [String: Any], let items = tracksDict["items"] as? [[String: Any]] else {
            throw SpotifyError.searchFailed
        }
        var tracks: [Track] = items.compactMap { item in
            guard let id = item["id"] as? String,
                  let name = item["name"] as? String,
                  let artists = item["artists"] as? [[String: Any]],
                  let artistName = artists.first?["name"] as? String,
                  let uri = item["uri"] as? String,
                  let popularity = item["popularity"] as? Int else { return nil }
            // Filter by popularity if needed
            if let minPopularity = minPopularity, popularity < minPopularity { return nil }
            if let maxPopularity = maxPopularity, popularity > maxPopularity { return nil }
            return Track(id: id, name: name, artist: artistName, uri: uri, previewUrl: nil, albumArtUrl: nil)
        }
        // Shuffle tracks for randomness
        tracks.shuffle()
        return tracks
    }
} 
