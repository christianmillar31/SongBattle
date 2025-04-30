import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            GameView()
                .tabItem {
                    Label("Game", systemImage: "music.note")
                }
                .tag(0)
            
            TeamsView()
                .tabItem {
                    Label("Teams", systemImage: "person.3")
                }
                .tag(1)
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(2)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
} 