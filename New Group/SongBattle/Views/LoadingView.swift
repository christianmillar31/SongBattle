import SwiftUI

struct LoadingView: View {
    @State private var isAnimating = false
    @State private var showText = false
    
    private let noteSymbols = ["♪", "♫", "♬", "♩", "♭"]
    @State private var noteOffsets: [CGSize] = Array(repeating: .zero, count: 5)
    
    var body: some View {
        ZStack {
            // Background gradient
            ColorTheme.primaryGradient
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Animated music notes
                ZStack {
                    ForEach(0..<5) { index in
                        Text(noteSymbols[index])
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                            .offset(noteOffsets[index])
                            .opacity(isAnimating ? 1 : 0)
                            .animation(
                                Animation.easeInOut(duration: 1.5)
                                    .repeatForever()
                                    .delay(Double(index) * 0.2),
                                value: noteOffsets[index]
                            )
                    }
                }
                
                // App title
                Text("SongBattle")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .opacity(showText ? 1 : 0)
                    .scaleEffect(showText ? 1 : 0.8)
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: showText)
                
                // Loading indicator
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                    .opacity(showText ? 1 : 0)
                    .animation(.easeIn.delay(0.3), value: showText)
            }
        }
        .onAppear {
            startAnimations()
        }
    }
    
    private func startAnimations() {
        // Animate notes
        for i in 0..<5 {
            withAnimation {
                noteOffsets[i] = CGSize(
                    width: CGFloat.random(in: -50...50),
                    height: CGFloat.random(in: -100...(-50))
                )
            }
        }
        
        // Start animations
        withAnimation {
            isAnimating = true
        }
        
        // Show text with delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation {
                showText = true
            }
        }
    }
}

#Preview {
    LoadingView()
} 