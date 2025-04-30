import SwiftUI

struct SettingsView: View {
    @ObservedObject var spotifyService: SpotifyService
    @State private var showingSpotifyLogin = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Spotify Integration")) {
                    if spotifyService.isConnected {
                        HStack {
                            Text("Connected to Spotify")
                            Spacer()
                            Button("Disconnect") {
                                spotifyService.disconnect()
                            }
                            .foregroundColor(.red)
                        }
                    } else {
                        Button("Connect to Spotify") {
                            spotifyService.connect()
                        }
                        
                        if let error = spotifyService.authenticationError {
                            Text(error.localizedDescription)
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }
                }
                
                Section(header: Text("Game Settings")) {
                    Toggle("Auto-play next song", isOn: .constant(true))
                    Toggle("Show song progress", isOn: .constant(true))
                    Toggle("Enable sound effects", isOn: .constant(true))
                }
                
                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(spotifyService: SpotifyService())
    }
} 
