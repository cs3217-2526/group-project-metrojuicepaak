import SwiftUI

struct SamplerView: View {
    @Bindable var viewModel: SamplerViewModel
    
    let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)
    
    var body: some View {
        VStack(spacing: 20) {
            // MARK: - Top Control Section
            VStack {
                Text("Session Controls")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 20) {
                    if viewModel.isRecording {
                        Text("🎙️ Recording...")
                            .foregroundStyle(.red)
                            .font(.headline)
                    } else if viewModel.isPlaying {
                        Text("▶️ Playing...")
                            .foregroundStyle(.green)
                            .font(.headline)
                    }
                    
                    Spacer()
                    
                    // Edit Mode Toggle
                    Toggle("Edit Mode", isOn: $viewModel.isEditMode)
                        .toggleStyle(.button)
                        .tint(.orange)
                }
                .padding(.horizontal)
            }
            .frame(height: 60)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(12)
            
            // MARK: - 4x4 Sampler Grid
            LazyVGrid(columns: columns, spacing: 12) {
                // Iterate directly over the 0-15 indices
                ForEach(0..<16, id: \.self) { index in
                    let clipNode = viewModel.pads[index]
                    
                    SamplerPadButton(
                        padIndex: index,
                        viewModel: viewModel,
                        clipNode: clipNode,
                        uiElements: SamplerPadButtonUIElements()
                    )
                    // Visual feedback for Edit Mode
                    .opacity(viewModel.isEditMode && clipNode == nil ? 0.5 : 1.0)
                    .overlay(
                        viewModel.isEditMode && clipNode != nil
                        ? RoundedRectangle(cornerRadius: 12).stroke(Color.orange, lineWidth: 3)
                        : nil
                    )
                }
            }
            .padding()
        }
        .padding()
        
        // MARK: - Editor Sheet Navigation
        .sheet(item: $viewModel.audioClipToEdit) { clipNode in
            let editorViewModel = SamplerWaveformEditorViewModel(
                clipNode: clipNode,
                playbackService: viewModel.playbackService,
                sessionManager: viewModel.audioSampleRepoVM
            )
            WaveformEditorView(viewModel: editorViewModel)
        }
        
        // MARK: - Sample Picker Sheet Navigation
        .sheet(isPresented: Binding(
            get: { viewModel.padToAssign != nil },
            set: { if !$0 { viewModel.padToAssign = nil } }
        )) {
            if let padIndex = viewModel.padToAssign {
                SamplePickerView(sessionManager: viewModel.audioSampleRepoVM) { selectedNode in
                    viewModel.assignClipNode(selectedNode, toPad: padIndex)
                }
            }
        }
    }
}
