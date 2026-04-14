import SwiftUI
/// The modal interface for visually trimming audio samples.
///
/// `WaveformEditorView` translates continuous physical drag gestures into normalized
/// ratio values (`0.0` to `1.0`) and pushes them to the `WaveformEditorViewModel`.
///
struct WaveformEditorView: View {
    
    /// The sandbox environment managing the temporary edit state.
    let viewModel: WaveformEditorViewModel
    
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Drag State Anchors
    
    /// Captures the handle's location at the start of a drag to calculate smooth relative movement.
    @State private var lastStartRatio: CGFloat = 0.0
    
    /// Captures the handle's location at the start of a drag to calculate smooth relative movement.
    @State private var lastEndRatio: CGFloat = 1.0
    
    var body: some View {
        VStack(spacing: 20) {
            
            // MARK: - Toolbar
            HStack {
                Button("Cancel") {
                    viewModel.cancelEdits()
                    dismiss()
                }
                .foregroundColor(.red)
                
                Spacer()
                Text("Edit Sample").font(.headline)
                Spacer()
                
                Button("Save") {
                    viewModel.saveEdits()
                    dismiss()
                }
                .bold()
            }
            .padding()
            
            // MARK: - The Custom Waveform Editor
            // GeometryReader provides the physical pixel width needed to convert
            // the ViewModel's abstract ratios [0, 1] into actual screen coordinates.
            GeometryReader { geometry in
                let width = geometry.size.width
                let startRatio = CGFloat(viewModel.tempStartRatio)
                let endRatio = CGFloat(viewModel.tempEndRatio)
                
                ZStack(alignment: .leading) {
                    
                    // Draw the High-Res Waveform Background
                    if let waveform = viewModel.waveformData {
                        SamplerThumbnailView(data: waveform, strokeColor: .cyan)
                    } else {
                        Text("Loading visual...")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    
                    // The Darkened "Trimmed Out" Overlays
                    // Visually grays out the portions of the audio that will be deleted.
                    Rectangle()
                        .fill(Color.black.opacity(0.6))
                        .frame(width: startRatio * width)
                    
                    Rectangle()
                        .fill(Color.black.opacity(0.6))
                        .frame(width: (1.0 - endRatio) * width)
                        .offset(x: endRatio * width)
                    
                    // Left Handle (Start Time)
                    TrimHandle()
                        .offset(x: startRatio * width)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    // Instantly halt audio if the user starts dragging
                                    viewModel.stopPreview()
                                    
                                    // Calculate physical distance moved as a percentage of total width
                                    let deltaRatio = value.translation.width / width
                                    let proposedRatio = lastStartRatio + deltaRatio
                                    
                                    // Clamp logic: Cannot go below 0.0, and cannot cross the End handle.
                                    let clampedRatio = max(0.0, min(proposedRatio, endRatio - 0.05))
                                    viewModel.tempStartRatio = Double(clampedRatio)
                                }
                                .onEnded { _ in lastStartRatio = startRatio }
                        )

                    // Right Handle (End Time)
                    TrimHandle()
                        .offset(x: (endRatio * width) - 4) // Offset by physical handle width to align perfectly
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    // Instantly halt audio if the user starts dragging
                                    viewModel.stopPreview()
                                    
                                    let deltaRatio = value.translation.width / width
                                    let proposedRatio = lastEndRatio + deltaRatio
                                    
                                    // Clamp logic: Cannot go above 1.0, and cannot cross the Start handle.
                                    let clampedRatio = min(1.0, max(proposedRatio, startRatio + 0.05))
                                    viewModel.tempEndRatio = Double(clampedRatio)
                                }
                                .onEnded { _ in lastEndRatio = endRatio }
                        )
                }
                .onAppear {
                    // Initialize drag anchors when the view first loads
                    self.lastStartRatio = startRatio
                    self.lastEndRatio = endRatio
                }
                .task {
                    // Guarantee the heavy waveform generation is only executed once per editing session.
                    if viewModel.waveformData == nil {
                        await viewModel.generateThumbnail(resolution: Int(width))
                    }
                }
            }
            .frame(height: 150)
            .background(Color.black.opacity(0.8))
            .cornerRadius(8)
            .padding(.horizontal)
            
            // MARK: - Playback Controls
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
            Spacer()
        }
    }
}


// MARK: - Helper Views

/// A reusable subview representing the visual drag boundaries in the Waveform Editor.
struct TrimHandle: View {
    var body: some View {
        Rectangle()
            .fill(Color.white)
            .frame(width: 4) // The visible thin white line
            .overlay(
                // UX TRICK: An invisible, wider rectangle layered on top to dramatically
                // increase the touch-target area, making it easier for users to grab the handle.
                Rectangle()
                    .fill(Color.white.opacity(0.01))
                    .frame(width: 30)
            )
    }
}


// MARK: - Memory Container

/// A critical architectural wrapper that protects the Editor's memory lifecycle.
///
/// Because the parent `SamplerView` redraws aggressively in response to grid events,
/// any struct initialized directly inside its `.sheet` closure will be destroyed and
/// recreated constantly.
///
/// `WaveformEditorContainer` solves this by capturing the `WaveformEditorViewModel`
/// inside an `@State` property. This instructs the SwiftUI rendering engine to allocate
/// the memory exactly once and shield it from parent view updates, preventing the
/// user's slider edits and cached waveforms from being unexpectedly wiped out.
struct WaveformEditorContainer: View {
    
    @State private var viewModel: WaveformEditorViewModel?
    
    /// Initializes the container and permanently anchors the ViewModel in memory.
    init(orchestrator: SamplerViewModel, sampleID: ObjectIdentifier) {
        // Wrap the factory method in a State initializer to guarantee single execution.
        _viewModel = State(initialValue: orchestrator.getEditorViewModel(for: sampleID))
    }
    
    var body: some View {
        if let vm = viewModel {
            WaveformEditorView(viewModel: vm)
        } else {
            Text("Error loading sample editor.")
                .foregroundColor(.red)
        }
    }
}
