import SwiftUI

struct CategorySelectionView: View {
    @ObservedObject var viewModel: CategorySelectionViewModel
    @Environment(\.dismiss) var dismiss
    
    init(gameService: GameService) {
        self.viewModel = CategorySelectionViewModel(gameService: gameService)
    }
    
    var body: some View {
        NavigationView {
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
            .navigationTitle("Music Categories")
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button("Clear All") {
                    Task {
                        await viewModel.clearCategories()
                    }
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