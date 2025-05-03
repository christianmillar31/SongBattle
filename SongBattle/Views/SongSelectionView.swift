import SwiftUI

struct SongSelectionView: View {
    @State private var selectedGenre: String = "Pop"
    @State private var selectedDecade: String = "2020s"
    @State private var selectedDifficulty: String = "Easy"
    let genres = ["Pop", "Rock", "Hip-Hop", "Jazz", "Classical", "Country", "Electronic", "R&B", "Reggae"]
    let decades = ["1960s", "1970s", "1980s", "1990s", "2000s", "2010s", "2020s"]
    let difficulties = ["Easy", "Medium", "Hard"]
    var onStart: ((String, String, String) -> Void)?
    var body: some View {
        VStack(spacing: 24) {
            Text("Select Song Settings")
                .font(.title)
                .padding(.top)
            Picker("Genre", selection: $selectedGenre) {
                ForEach(genres, id: \ .self) { genre in
                    Text(genre)
                }
            }
            .pickerStyle(MenuPickerStyle())
            Picker("Decade", selection: $selectedDecade) {
                ForEach(decades, id: \ .self) { decade in
                    Text(decade)
                }
            }
            .pickerStyle(MenuPickerStyle())
            Picker("Difficulty", selection: $selectedDifficulty) {
                ForEach(difficulties, id: \ .self) { diff in
                    Text(diff)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            Button(action: {
                onStart?(selectedGenre, selectedDecade, selectedDifficulty)
            }) {
                Text("Start Game")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.top)
            Spacer()
        }
        .padding()
    }
}

// Preview
struct SongSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        SongSelectionView()
    }
} 