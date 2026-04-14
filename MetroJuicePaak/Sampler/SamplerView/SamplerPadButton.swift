////
////  SamplerPadButton.swift
////  MetroJuicePaak
////
////  Created by Noah Ang Shi Hern on 22/3/26.
////
import SwiftUI
//
//struct SamplerPadButton: View {
//    let padIndex: Int
//    let viewModel: SamplerViewModel       // For routing actions (play/record)
//    let clipNode: AudioClipViewModel?     // For observing the visual state
//    let uiElements: SamplerPadButtonUIElements
//    
//    @State private var isBeingPressed = false
//    
//    var body: some View {
//        ZStack {
//            // Background
//            RoundedRectangle(cornerRadius: 12)
//                .fill(uiElements.color.swiftUIColor)
//                .shadow(color: .black.opacity(0.3), radius: isBeingPressed ? 2 : 4, y: isBeingPressed ? 2 : 4)
//            
//            // Foreground Content
//            if let node = clipNode {
//                if let waveform = node.thumbnailData {
//                    // Draw the cached waveform
//                    SampleThumbnailView(data: waveform)
//                } else {
//                    // Fallback while generating, or if it failed
//                    Text(node.sample.name)
//                        .font(.caption)
//                        .bold()
//                        .foregroundColor(.white)
//                        .multilineTextAlignment(.center)
//                        .padding()
//                }
//            } else {
//                // Empty Pad
//                if let image = uiElements.image {
//                    Image(uiImage: image)
//                        .resizable()
//                        .aspectRatio(contentMode: .fit)
//                        .padding(8)
//                }
//            }
//        }
//        .aspectRatio(1, contentMode: .fit)
//        .scaleEffect(isBeingPressed ? 0.95 : 1.0)
//        .gesture(
//            DragGesture(minimumDistance: 0)
//                .onChanged { _ in
//                    if !isBeingPressed {
//                        withAnimation(.easeInOut(duration: 0.1)) { isBeingPressed = true }
//                        Task { await viewModel.handlePadPressed(padIndex: padIndex) }
//                    }
//                }
//                .onEnded { _ in
//                    withAnimation(.easeInOut(duration: 0.1)) { isBeingPressed = false }
//                    Task { await viewModel.handlePadReleased(padIndex: padIndex) }
//                }
//        )
//        .background(
//            GeometryReader { geometry in
//                Color.clear
//                    .task(id: clipNode?.sample.id) {
//                        if let node = clipNode, node.thumbnailData == nil {
//                            
//                            await node.refreshThumbnail(uiWidth: Int(geometry.size.width))
//                        }
//                    }
//            }
//        )
//    }
//}
import SwiftUI

struct SamplerPadButton: View {
    // MARK: - ViewModels
    // The local display model that formats the name and waveform (Read-Only)
    let localViewModel: SamplerPadViewModel
    
    // The global orchestrator that handles actual logic (Interactions)
    let orchestrator: SamplerViewModel
    
    // The physical slot this pad occupies (0-15)
    let padIndex: Int
    
    // MARK: - UI State
    // purely local state to make the button visually shrink when pressed
    @State private var isPressed: Bool = false
    
    var body: some View {
        ZStack {
            // 1. Background
            RoundedRectangle(cornerRadius: 8)
                .fill(isPressed ? Color.gray.opacity(0.4) : Color.gray.opacity(0.2))
                .shadow(color: Color.black.opacity(0.2), radius: isPressed ? 1 : 4, x: 0, y: isPressed ? 1 : 2)
            
            // 2. Waveform Image
            if let img = localViewModel.thumbnailImage {
                img
                    .resizable()
                    .scaledToFit()
                    .padding(4)
            }
            
            // 3. Display Name
            Text(localViewModel.displayName)
                .font(.caption)
                .bold()
                .lineLimit(1)
                .foregroundColor(.primary)
                .padding(.horizontal, 4)
                .padding(.bottom, 4)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        // Visual press animation
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.snappy, value: isPressed)
        
        // MARK: - The Gesture Router
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    // --- PRESS DOWN ---
                    if !isPressed {
                        isPressed = true
                        
                        // We only start recording if NOT in edit mode AND the pad is empty
                        if !orchestrator.isEditMode && orchestrator.padAssignments[padIndex] == nil {
                            Task {
                                await orchestrator.startRecording(on: padIndex)
                            }
                        }
                    }
                }
                .onEnded { _ in
                    // --- RELEASE UP ---
                    isPressed = false
                    
                    if orchestrator.isEditMode {
                        // In Edit Mode, a release counts as a "Tap" to open menus
                        orchestrator.handlePadTap(padIndex: padIndex)
                    } else {
                        // In Play Mode...
                        if orchestrator.padAssignments[padIndex] == nil {
                            // If it was empty, the user was holding to record. Stop recording!
                            Task {
                                await orchestrator.stopRecording(on: padIndex)
                            }
                        } else {
                            // If it had a sample, the press down did nothing,
                            // but releasing triggers the playback!
                            orchestrator.handlePadTap(padIndex: padIndex)
                        }
                    }
                }
        )
        // MARK: - Reactivity Magic
        // Tells the local ViewModel to fetch a new image if the trim ratios change in the background
        .task(id: [localViewModel.waveformSource?.startTimeRatio, localViewModel.waveformSource?.endTimeRatio]) {
            await localViewModel.generateThumbnail(resolution: 100)
        }
    }
}
