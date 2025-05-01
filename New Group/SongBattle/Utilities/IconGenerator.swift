import SwiftUI

struct IconGenerator: View {
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.478, green: 0.329, blue: 0.949), // Our primary purple
                    Color(red: 0.686, green: 0.196, blue: 0.851)  // Our accent pink
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Music note design
            ZStack {
                // Outer circle
                Circle()
                    .fill(.white.opacity(0.15))
                    .frame(width: 180, height: 180)
                
                // Inner circle with note
                Circle()
                    .fill(.white)
                    .frame(width: 150, height: 150)
                    .overlay(
                        Text("♫")
                            .font(.system(size: 80))
                            .foregroundColor(Color(red: 0.478, green: 0.329, blue: 0.949))
                    )
                
                // Battle elements
                ForEach(0..<2) { i in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.white)
                        .frame(width: 40, height: 8)
                        .rotationEffect(.degrees(45 + Double(i * 90)))
                        .offset(x: 85, y: 85)
                }
            }
        }
        .frame(width: 1024, height: 1024) // Size for App Store icon
    }
}

extension IconGenerator {
    // Function to generate and save icons
    static func generateIcons() {
        let sizes = [
            (size: 20, scales: [2, 3]),      // Notification icon
            (size: 29, scales: [2, 3]),      // Settings icon
            (size: 40, scales: [2, 3]),      // Spotlight icon
            (size: 60, scales: [2, 3]),      // App icon
            (size: 1024, scales: [1])        // App Store icon
        ]
        
        let view = IconGenerator()
        
        for (size, scales) in sizes {
            for scale in scales {
                let finalSize = size * scale
                let renderer = ImageRenderer(content: view)
                renderer.proposedSize = .init(width: finalSize, height: finalSize)
                
                if let image = renderer.uiImage {
                    let fileManager = FileManager.default
                    let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    
                    let filename = size == 1024 ? "ios-marketing.png" : "Icon-\(size)@\(scale)x.png"
                    let fileURL = documentsPath.appendingPathComponent(filename)
                    
                    if let data = image.pngData() {
                        try? data.write(to: fileURL)
                        print("Generated icon: \(filename)")
                        print("Saved to: \(fileURL.path)")
                    }
                }
            }
        }
    }
}

#Preview {
    IconGenerator()
} 