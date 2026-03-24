//
//  WaveFormEditorView.swift
//  MetroJuicePaak
//
//  Created by proglab on 23/3/26.
//

import SwiftUI
import Combine

// Mocking the protocol for now so it compiles
protocol SampleViewModelProtocol: ObservableObject {
    var waveformAmplitudes: [CGFloat] { get }
}

struct WaveformEditorView<ViewModel: SampleViewModelProtocol>: View {
    @ObservedObject var viewModel: ViewModel
    
    @State private var startRatio: CGFloat = 0.0
    @State private var endRatio: CGFloat = 1.0
    @State private var lastStartRatio: CGFloat = 0.0
    @State private var lastEndRatio: CGFloat = 1.0
    
    var body: some View {
        VStack {
            if viewModel.waveformAmplitudes.isEmpty {
                Text("Extracting audio buffer...")
                    .foregroundStyle(.secondary)
            } else {
                GeometryReader { geometry in
                    // Use a leading ZStack so our X offsets start perfectly from 0
                    ZStack(alignment: .leading) {
                        
                        // 1. The Waveform (from Step 2)
                        Path { path in
                            let width = geometry.size.width
                            let height = geometry.size.height
                            let amplitudes = viewModel.waveformAmplitudes
                            let count = amplitudes.count
                            
                            guard count > 1 else { return }
                            
                            for (index, amplitude) in amplitudes.enumerated() {
                                let x = width * CGFloat(index) / CGFloat(count - 1)
                                let y = height - (amplitude * height)
                                
                                if index == 0 {
                                    path.move(to: CGPoint(x: x, y: y))
                                } else {
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                            }
                        }
                        .stroke(Color.cyan, lineWidth: 2)
                        
                        // 2. The Left Trim Handle (Start Time)
                        TrimHandle()
                            .offset(x: startRatio * geometry.size.width)
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        // 1. Calculate how much the ratio changed based on the total width
                                        let deltaRatio = value.translation.width / geometry.size.width
                                        
                                        // 2. Add that delta to the ANCHORED last ratio, not the active one
                                        let proposedRatio = lastStartRatio + deltaRatio
                                        
                                        // 3. Clamp logic: Cannot go below 0.0, and cannot cross the right handle
                                        // We leave a tiny 0.01 buffer so the handles don't perfectly overlap and get stuck
                                        startRatio = max(0.0, min(proposedRatio, endRatio - 0.01))
                                    }
                                    .onEnded { _ in
                                        // 4. When the drag finishes, update the anchor for the next time it's touched
                                        lastStartRatio = startRatio
                                    }
                            )

                        // 3. The Right Trim Handle (End Time)
                        TrimHandle()
                            .offset(x: (endRatio * geometry.size.width) - 4)
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        let deltaRatio = value.translation.width / geometry.size.width
                                        let proposedRatio = lastEndRatio + deltaRatio
                                        
                                        // Clamp logic: Cannot go above 1.0, and cannot cross the left handle
                                        endRatio = min(1.0, max(proposedRatio, startRatio + 0.01))
                                    }
                                    .onEnded { _ in
                                        lastEndRatio = endRatio
                                    }
                            )
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .frame(height: 150)
        .frame(maxWidth: .infinity)
        .background(Color.black.opacity(0.8))
        .cornerRadius(8)
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



class PreviewMockSampleViewModel: SampleViewModelProtocol {
    @Published var waveformAmplitudes: [CGFloat] = []
    
    init() {
        // Generate dummy peaks so the Canvas has something to draw
        self.waveformAmplitudes = (0..<100).map { _ in
            CGFloat.random(in: 0.1...1.0)
        }
    }
}

// 2. The actual preview macro
#Preview("Waveform Editor") {
    WaveformEditorView(viewModel: PreviewMockSampleViewModel())
        .padding()
}
