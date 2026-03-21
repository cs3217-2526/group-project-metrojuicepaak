//
//  ContentView.swift
//  MetroJuicePaak
//
//  Created by Noah Ang Shi Hern on 17/3/26.
//

import SwiftUI

struct SamplerPad: Identifiable {
    let id: Int
    var color: Color
    var image: String?
    
    init(id: Int, color: Color = .blue, image: String? = nil) {
        self.id = id
        self.color = color
        self.image = image
    }
}

struct SamplerView: View {
    @State private var pads: [SamplerPad] = (0..<16).map { SamplerPad(id: $0) }
    
    let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)
    
    var body: some View {
        VStack(spacing: 20) {
            // MARK: - Top Control Section
            // Reserved space for additional buttons/controls
            VStack {
                Text("Control Section")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                // Add your control buttons here later
                HStack {
                    // Placeholder for future controls
                }
                .frame(height: 60)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(12)
            
            // MARK: - 4x4 Sampler Grid
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(pads) { pad in
                    SamplerButton(pad: pad) {
                        handlePadTap(pad.id)
                    }
                }
            }
            .padding()
        }
        .padding()
    }
    
    private func handlePadTap(_ id: Int) {
        print("Pad \(id) tapped")
        // Add your sampler logic here
    }
}

struct SamplerButton: View {
    let pad: SamplerPad
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = true
            }
            action()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = false
                }
            }
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(pad.color)
                    .shadow(color: .black.opacity(0.3), radius: isPressed ? 2 : 4, y: isPressed ? 2 : 4)
                
                if let imageName = pad.image {
                    Image(systemName: imageName)
                        .font(.title)
                        .foregroundStyle(.white)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .scaleEffect(isPressed ? 0.95 : 1.0)
    }
}

#Preview {
    SamplerView()
}
