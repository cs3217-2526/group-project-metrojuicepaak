import SwiftUI

/// A highly interactive SwiftUI view representing a single slot on the drum machine grid.
///
/// `SamplerPadButton` acts as the physical touch surface for the user. It delegates all actual
/// business logic back to the `SamplerViewModel` (Orchestrator), while relying on the
/// `SamplerPadViewModel` strictly for read-only visual data (like the waveform thumbnail).
///
/// **Interaction Routing:**
/// - **Tap:** Triggers playback (in normal mode) or opens the editor/picker (in edit mode).
/// - **Hold:** Initiates hardware microphone recording if the pad is empty and not in edit mode.
struct SamplerPadButton: View {
    
    /// The physical hardware slot (0-15) this pad represents.
    let padIndex: Int
    
    /// The central router for all gesture actions.
    let orchestrator: SamplerViewModel
    
    /// The lightweight, read-only cache of this specific pad's visual data. `nil` if the pad is empty.
    let localViewModel: SamplerPadViewModel?
    
    /// Static styling configuration (colors, default icons).
    let uiElements: SamplerPadButtonUIElements
    
    // MARK: - Gesture State
    
    /// Tracks the physical touch state to provide immediate visual feedback (e.g., scale and shadow reduction).
    @State private var isBeingPressed = false
    
    /// A reference to the asynchronous countdown timer used to distinguish a quick tap from a "Hold to Record" gesture.
    @State private var pressTask: Task<Void, Never>? = nil
    
    var body: some View {
        ZStack {
            // Background Layer
            RoundedRectangle(cornerRadius: 12)
                .fill(uiElements.color.swiftUIColor)
                .shadow(color: .black.opacity(0.3), radius: isBeingPressed ? 2 : 4, y: isBeingPressed ? 2 : 4)
                .accessibilityIdentifier("SamplerPad_\(padIndex)")
                .accessibilityAddTraits(.isButton)
            
            // Foreground Content Layer
            if let node = localViewModel {
                if let waveform = node.waveformData {
                    // Draw the cached waveform
                    SamplerThumbnailView(data: waveform, strokeColor: .white)
                } else {
                    // Fallback while generating, or if generation failed
                    Text(node.displayName)
                        .font(.caption)
                        .bold()
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding()
                }
            } else {
                // Empty Pad Visuals
                if let image = uiElements.image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(8)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .scaleEffect(isBeingPressed ? 0.95 : 1.0) // Visual click feedback
        
        // MARK: Gesture Routing
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isBeingPressed {
                        withAnimation(.easeInOut(duration: 0.1)) { isBeingPressed = true }
                        
                        // Action: Hold to Record (if empty and not edit mode)
                        if !orchestrator.isEditMode && localViewModel == nil {
                            
                            // Start the 1-second countdown
                            pressTask = Task {
                                do {
                                    // Sleep for 1 second
                                    try await Task.sleep(nanoseconds: 1_000_000_000)
                                    
                                    // If the user didn't lift their finger, start the mic!
                                    if !Task.isCancelled {
                                        await orchestrator.startRecording(on: padIndex)
                                    }
                                } catch {
                                    // Task was cancelled (finger lifted early), do nothing
                                }
                            }
                        }
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.1)) { isBeingPressed = false }
                    
                    // Action: Taps and Releases
                    if orchestrator.isEditMode {
                        orchestrator.handlePadTap(padIndex: padIndex)
                    } else {
                        if localViewModel == nil {
                            // Finger lifted early -> Cancel the recording countdown.
                            pressTask?.cancel()
                            pressTask = nil
                            
                            // Only stop recording if the microphone actually turned on
                            if orchestrator.isRecordingPadIndex == padIndex {
                                Task { await orchestrator.stopRecording(on: padIndex) }
                            }
                        } else {
                            // Pad has audio, just play it
                            orchestrator.handlePadTap(padIndex: padIndex)
                        }
                    }
                }
        )
        // MARK: Reactive Thumbnail Generation
        // Automatically re-fires if the underlying domain model's trim ratios change.
        .task(id: [localViewModel?.waveformSource?.startTimeRatio, localViewModel?.waveformSource?.endTimeRatio]) {
            if let node = localViewModel {
                await node.generateThumbnail(resolution: 100)
            }
        }
    }
}
