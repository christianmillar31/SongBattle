import SwiftUI

struct AddTeamView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject var viewModel: TeamsViewModel
    
    var body: some View {
        NavigationView {
            VStack {
                TextField("Team Name", text: $viewModel.teamName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                
                Button(action: {
                    Task {
                        await viewModel.addTeam()
                        dismiss()
                    }
                }) {
                    Text("Add Team")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(viewModel.teamName.isEmpty ? Color.gray : Color.theme.accent)
                        .cornerRadius(10)
                }
                .disabled(viewModel.teamName.isEmpty)
                .padding()
                
                Spacer()
            }
            .navigationTitle("Add Team")
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                }
            )
        }
    }
} 