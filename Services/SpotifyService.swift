print("DEBUG: Setting up Spotify")
let redirectURL = URL(string: Configuration.spotifyRedirectURI)!
let configuration = SPTConfiguration(
    clientID: Configuration.spotifyClientId,
    redirectURL: redirectURL,
    campaign: "songbattle_app"
)

appRemote = SPTAppRemote(configuration: configuration, logLevel: .debug)

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
        sessionManager?.initiateSession(with: scope)
    }
} 