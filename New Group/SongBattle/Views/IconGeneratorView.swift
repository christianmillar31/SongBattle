import SwiftUI

struct IconGeneratorView: View {
    var body: some View {
        VStack(spacing: 20) {
            IconGenerator()
                .frame(width: 200, height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 40))
                .shadow(radius: 10)
            
            Button("Generate Icons") {
                IconGenerator.generateIcons()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

#Preview {
    IconGeneratorView()
} 