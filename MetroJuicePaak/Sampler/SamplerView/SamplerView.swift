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
                    // Edit Mode Toggle
                    Toggle("Edit Mode", isOn: Bindable(viewModel).isEditMode)
                        .toggleStyle(.button)
                        .tint(.orange)
                }
                .frame(height: 60)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(12)
            
            // MARK: - 4x4 Sampler Grid
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(Array(viewModel.pads.values).sorted(by: { $0.id.uuidString < $1.id.uuidString })) { pad in
                    SamplerPadButton(id: pad.id, viewModel: viewModel, isSampleLoaded: pad.isSampleLoaded)
                        // Optional: Give visual feedback when edit mode is on
                        .opacity(viewModel.isEditMode && !pad.isSampleLoaded ? 0.5 : 1.0)
                        .overlay(
                            viewModel.isEditMode && pad.isSampleLoaded
                            ? RoundedRectangle(cornerRadius: 12).stroke(Color.orange, lineWidth: 3)
                            : nil
                        )
                }
            }
            .padding()
        }
        .padding()
        // MARK: - Editor Sheet Navigation
        // This watches the padToEdit variable. When it's not nil, it slides up a view.
        .sheet(item: Bindable(viewModel).padToEdit) { pad in
            VStack {
                Text("Editor for Pad: \(pad.id.uuidString.prefix(5))")
                    .font(.headline)
                    .padding()
                
                // Instantiate the ViewModel and the View
                let editorViewModel = SampleEditorViewModel(pad: pad, AudioService: viewModel.audioService)
                WaveformEditorView(viewModel: editorViewModel)
                    .padding()
                
                Button("Done") {
                    // Save the math back to the model
                    editorViewModel.saveEdits()
                    viewModel.padToEdit = nil // Dismiss sheet
                }
                .padding()
                .buttonStyle(.borderedProminent)
            }
            .presentationDetents([.medium, .large])
        }
    }
}

//#Preview("Empty Sampler") {
//    SamplerView(viewModel: .mockForPreview())
//}
//
//#Preview("With Loaded Samples") {
//    SamplerView(viewModel: .mockWithSamples())
//}
