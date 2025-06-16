import SwiftUI

struct CategorySelectionView: View {
    @ObservedObject var viewModel: CategorySelectionViewModel
    @Environment(\.dismiss) var dismiss
    
    init(gameService: GameService) {
        self.viewModel = CategorySelectionViewModel(gameService: gameService)
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Selected categories summary
                if viewModel.selectedCategories.isEmpty {
                    Text("No categories selected - all music will be included")
                        .foregroundColor(.secondary)
                        .padding(.top)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(viewModel.selectedCategories)) { category in
                                Text(category.name)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.blue)
                                    .cornerRadius(8)
                            }
                        }
                        .padding(.top)
                    }
                }
                List {
                    Section(header: Text("Decades")) {
                        ForEach(viewModel.decades) { category in
                            CategoryToggleRow(
                                category: category,
                                isSelected: viewModel.isSelected(category),
                                action: {
                                    Task {
                                        await viewModel.toggleCategory(category)
                                    }
                                }
                            )
                        }
                    }
                    Section(header: Text("Genres")) {
                        ForEach(viewModel.genres) { category in
                            CategoryToggleRow(
                                category: category,
                                isSelected: viewModel.isSelected(category),
                                action: {
                                    Task {
                                        await viewModel.toggleCategory(category)
                                    }
                                }
                            )
                        }
                    }
                }
                // Submit button at the bottom
                Button(action: { dismiss() }) {
                    Text("Submit")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding([.horizontal, .bottom])
                }
            }
            .navigationTitle("Music Categories")
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                }
            )
        }
    }
}

struct CategoryToggleRow: View {
    let category: MusicCategory
    let isSelected: Bool
    let action: () async -> Void
    
    var body: some View {
        Button(action: {
            Task {
                await action()
            }
        }) {
            HStack {
                Text(category.name)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                }
            }
        }
    }
}
