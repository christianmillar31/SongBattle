import Foundation
import SpotifyiOS

class SpotifyService: ObservableObject {
    @Published var isConnected = false
    @Published var currentTrack: Track?
    @Published var isPlaying = false
    
    private var appRemote: SPTAppRemote?
    private var configuration: SPTConfiguration?
    
    init() {
        setupSpotify()
    }
    
    private func setupSpotify() {
        configuration = SPTConfiguration(clientID: UserDefaults.standard.string(forKey: "spotifyClientId") ?? "",
                                       redirectURL: URL(string: "songbattle://spotify-callback")!)
        
        appRemote = SPTAppRemote(configuration: configuration!, logLevel: .debug)
        appRemote?.delegate = self
    }
    
    func connect() {
        appRemote?.connect()
    }
    
    func disconnect() {
        appRemote?.disconnect()
    }
    
    func play(track: Track) {
        appRemote?.playerAPI?.play(track.uri)
    }
    
    func pause() {
        appRemote?.playerAPI?.pause()
    }
    
    func resume() {
        appRemote?.playerAPI?.resume()
    }
    
    func skipNext() {
        appRemote?.playerAPI?.skip(toNext: nil)
    }
    
    func skipPrevious() {
        appRemote?.playerAPI?.skip(toPrevious: nil)
    }
}

extension SpotifyService: SPTAppRemoteDelegate {
    func appRemoteDidEstablishConnection(_ appRemote: SPTAppRemote) {
        isConnected = true
        appRemote.playerAPI?.delegate = self
        appRemote.playerAPI?.subscribe { [weak self] (_, error) in
            if let error = error {
                print("Error subscribing to player state: \(error.localizedDescription)")
            }
        }
    }
    
    func appRemote(_ appRemote: SPTAppRemote, didFailConnectionAttemptWithError error: Error?) {
        isConnected = false
        print("Failed to connect to Spotify: \(error?.localizedDescription ?? "Unknown error")")
    }
    
    func appRemote(_ appRemote: SPTAppRemote, didDisconnectWithError error: Error?) {
        isConnected = false
        print("Disconnected from Spotify: \(error?.localizedDescription ?? "No error")")
    }
}

extension SpotifyService: SPTAppRemotePlayerStateDelegate {
    func playerStateDidChange(_ playerState: SPTAppRemotePlayerState) {
        isPlaying = playerState.isPaused == false
        currentTrack = Track(
            id: playerState.track.uri,
            title: playerState.track.name,
            artist: playerState.track.artist.name,
            uri: playerState.track.uri
        )
    }
}

struct Track: Identifiable {
    let id: String
    let title: String
    let artist: String
    let uri: String
} 