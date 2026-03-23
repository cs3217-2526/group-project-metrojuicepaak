//
//  SamplerView.swift
//  MetroJuicePaak
//
//  Created by Noah Ang Shi Hern on 17/3/26.
//

import SwiftUI

struct SamplerView: View {
    @State private var viewModel: SamplerViewModel
    
    init (viewModel: SamplerViewModel) {
        self.viewModel = viewModel
    }
    
    let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)
    
    var body: some View {
        VStack(spacing: 20) {
            // MARK: - Top Control Section
            VStack {
                Text("Control Section")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                if viewModel.isRecording {
                    Text("Recording...")
                        .foregroundStyle(.red)
                        .font(.caption)
                } else if viewModel.isPlaying {
                    Text("Playing...")
                        .foregroundStyle(.red)
                        .font(.caption)
                }
                
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
                // Iterate over PRESENTATION models, not Model objects
                ForEach(Array(viewModel.pads.values).sorted(by: { $0.id.uuidString < $1.id.uuidString })) { pad in
                    SamplerPadButton(id: pad.id, viewModel: viewModel, isSampleLoaded: pad.isSampleLoaded)
                }
            }
            .padding()
        }
        .padding()
    }
}

//#Preview("Empty Sampler") {
//    SamplerView(viewModel: .mockForPreview())
//}
//
//#Preview("With Loaded Samples") {
//    SamplerView(viewModel: .mockWithSamples())
//}
