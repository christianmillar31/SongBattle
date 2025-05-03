import SwiftUI

struct ToolbarTestView: View {
    @State private var showingSettings = false

    var body: some View {
        NavigationView {
            Text("Hello, world!")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { showingSettings = true }) {
                            Image(systemName: "gear")
                        }
                    }
                }
        }
    }
}

#Preview {
    ToolbarTestView()
} 