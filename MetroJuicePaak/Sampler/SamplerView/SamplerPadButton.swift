//
//  SamplerPadButton.swift
//  MetroJuicePaak
//
//  Created by Noah Ang Shi Hern on 22/3/26.
//
import SwiftUI

struct SamplerPadButton: View {
    let padIndex: Int
    let viewModel: SamplerViewModel       // For routing actions (play/record)
    let clipNode: AudioClipViewModel?     // For observing the visual state
    let uiElements: SamplerPadButtonUIElements
    
    @State private var isBeingPressed = false
    
    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 12)
                .fill(uiElements.color.swiftUIColor)
                .shadow(color: .black.opacity(0.3), radius: isBeingPressed ? 2 : 4, y: isBeingPressed ? 2 : 4)
            
            // Foreground Content
            if let node = clipNode {
                if let waveform = node.thumbnailData {
                    // Draw the cached waveform
                    SampleThumbnailView(data: waveform)
                } else {
                    // Fallback while generating, or if it failed
                    Text(node.sample.name)
                        .font(.caption)
                        .bold()
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding()
                }
            } else {
                // Empty Pad
                if let image = uiElements.image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(8)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .scaleEffect(isBeingPressed ? 0.95 : 1.0)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isBeingPressed {
                        withAnimation(.easeInOut(duration: 0.1)) { isBeingPressed = true }
                        Task { await viewModel.handlePadPressed(padIndex: padIndex) }
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.1)) { isBeingPressed = false }
                    Task { await viewModel.handlePadReleased(padIndex: padIndex) }
                }
        )
        .background(
            GeometryReader { geometry in
                Color.clear
                    .task(id: clipNode?.sample.id) {
                        if let node = clipNode, node.thumbnailData == nil {
                            
                            await node.refreshThumbnail(uiWidth: Int(geometry.size.width))
                        }
                    }
            }
        )
    }
}
