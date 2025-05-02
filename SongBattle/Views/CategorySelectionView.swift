import SwiftUI

struct CategorySelectionView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject var viewModel: CategorySelectionViewModel
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Genres Section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Genres")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 10) {
                            ForEach(viewModel.genres) { category in
                                CategoryButton(
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
                    .padding()
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(15)
                    
                    // Decades Section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Decades")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 10) {
                            ForEach(viewModel.decades) { category in
                                CategoryButton(
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
                    .padding()
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(15)
                    
                    // Clear Selection Button
                    Button(action: {
                        Task {
                            await viewModel.clearCategories()
                        }
                    }) {
                        Text("Clear Selection")
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.red.opacity(0.3))
                            .cornerRadius(10)
                    }
                    .padding(.top)
                }
                .padding()
            }
            .navigationTitle("Select Categories")
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button("Done") {
                    dismiss()
                }
            )
        }
    }
}

struct CategoryButton: View {
    let category: MusicCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(category.name)
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(isSelected ? Color.theme.accent : Color.theme.accent.opacity(0.3))
                .cornerRadius(10)
        }
    }
} 