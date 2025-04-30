import SwiftUI

struct SettingsView: View {
    @AppStorage("spotifyClientId") private var spotifyClientId = ""
    @AppStorage("spotifyClientSecret") private var spotifyClientSecret = ""
    @State private var isSpotifyConnected = false
    @State private var showingSpotifyLogin = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Spotify Integration")) {
                    if isSpotifyConnected {
                        HStack {
                            Text("Connected to Spotify")
                            Spacer()
                            Button("Disconnect") {
                                // TODO: Implement Spotify disconnect
                                isSpotifyConnected = false
                            }
                            .foregroundColor(.red)
                        }
                    } else {
                        Button("Connect to Spotify") {
                            showingSpotifyLogin = true
                        }
                    }
                }
                
                Section(header: Text("Spotify API Credentials")) {
                    TextField("Client ID", text: $spotifyClientId)
                    SecureField("Client Secret", text: $spotifyClientSecret)
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
            .sheet(isPresented: $showingSpotifyLogin) {
                SpotifyLoginView(isPresented: $showingSpotifyLogin)
            }
        }
    }
}

struct SpotifyLoginView: View {
    @Binding var isPresented: Bool
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                } else {
                    Text("Connect to Spotify")
                        .font(.title)
                        .padding()
                    
                    Text("Please log in to your Spotify account to enable music playback.")
                        .multilineTextAlignment(.center)
                        .padding()
                    
                    Button(action: {
                        // TODO: Implement Spotify login
                        isLoading = true
                    }) {
                        Text("Log in with Spotify")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.green)
                            .cornerRadius(10)
                    }
                    .padding()
                }
            }
            .navigationBarItems(trailing: Button("Cancel") {
                isPresented = false
            })
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
} 