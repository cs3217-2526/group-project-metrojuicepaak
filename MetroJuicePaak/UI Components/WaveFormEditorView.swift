//
//  WaveFormEditorView.swift
//  MetroJuicePaak
//
//  Created by proglab on 23/3/26.
//

import SwiftUI

struct WaveformEditorView: View {
    @Bindable var viewModel: SamplerWaveformEditorViewModel
    
    // Store the drag anchors so the handles don't jump when touched
    @State private var lastStartRatio: CGFloat = 0.0
    @State private var lastEndRatio: CGFloat = 1.0
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Editing: \(viewModel.clipNode.sample.name)")
                .font(.headline)
            
            GeometryReader { geometry in
                let width = geometry.size.width
                
                // Directly read the ratios from the updated ViewModel
                let startRatio = CGFloat(viewModel.tempStartRatio)
                let endRatio = CGFloat(viewModel.tempEndRatio)
                
                ZStack(alignment: .leading) {
                    
                    // 1. Draw the High-Res Waveform Background
                    if let waveform = viewModel.clipNode.thumbnailData {
                        SampleThumbnailView(data: waveform, strokeColor: .cyan)
                    } else {
                        Text("Loading visual...")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    
                    // 2. The Darkened "Trimmed Out" overlays
                    Rectangle()
                        .fill(Color.black.opacity(0.6))
                        .frame(width: startRatio * width)
                    
                    Rectangle()
                        .fill(Color.black.opacity(0.6))
                        .frame(width: (1.0 - endRatio) * width)
                        .offset(x: endRatio * width)
                    
                    // 3. Left Handle (Start Time)
                    TrimHandle()
                        .offset(x: startRatio * width)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    Task { await viewModel.stopIfPlaying() }
                                    let deltaRatio = value.translation.width / width
                                    let proposedRatio = lastStartRatio + deltaRatio
                                    
                                    // Clamp: Cannot go below 0, cannot cross Right Handle
                                    let clampedRatio = max(0.0, min(proposedRatio, endRatio - 0.05))
                                    
                                    viewModel.tempStartRatio = Double(clampedRatio)
                                }
                                .onEnded { _ in lastStartRatio = startRatio }
                        )

                    // 4. Right Handle (End Time)
                    TrimHandle()
                        .offset(x: (endRatio * width) - 4) // offset by handle width
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    Task { await viewModel.stopIfPlaying() }
                                    let deltaRatio = value.translation.width / width
                                    let proposedRatio = lastEndRatio + deltaRatio
                                    
                                    // Clamp: Cannot go above 1, cannot cross Left Handle
                                    let clampedRatio = min(1.0, max(proposedRatio, startRatio + 0.05))
                                    
                                    viewModel.tempEndRatio = Double(clampedRatio)
                                }
                                .onEnded { _ in lastEndRatio = endRatio }
                        )
                }
                .onAppear {
                    // Initialize drag anchors when view loads
                    self.lastStartRatio = startRatio
                    self.lastEndRatio = endRatio
                }
            }
            .frame(height: 150)
            .background(Color.black.opacity(0.8))
            .cornerRadius(8)
            
            // Playback Controls
            HStack(spacing: 40) {
                Button {
                    Task { await viewModel.togglePreview() }
                } label: {
                    Image(systemName: viewModel.isPlayingPreview ? "stop.circle.fill" : "play.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(viewModel.isPlayingPreview ? .red : .cyan)
                        .contentTransition(.symbolEffect(.replace))
                }
            }
        }
        .padding()
    }
}

// A reusable subview for the visual drag handles
struct TrimHandle: View {
    var body: some View {
        Rectangle()
            .fill(Color.white)
            .frame(width: 4)
            .overlay(
                // A larger transparent area makes it easier for fat fingers to grab it on an iPad
                Rectangle()
                    .fill(Color.white.opacity(0.01))
                    .frame(width: 30)
            )
    }
}
