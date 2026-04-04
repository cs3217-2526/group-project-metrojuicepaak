import Foundation
import Observation

/// The central State Machine for the 4x4 Sampler Grid.
///
/// This ViewModel acts as the "Brain" of the main UI. It tracks physical touch events,
/// routes users between Play, Record, and Edit modes, and acts as the bridge
/// between the UI and the underlying Audio Services.
@Observable
class SamplerViewModel {
    
    // MARK: - Core State
    
    /// The 16 physical pads.
    /// An index containing `nil` represents an empty pad.
    /// An index containing an `AudioClipViewModel` represents an assigned, playable sample.
    var pads: [AudioClipViewModel?] = Array(repeating: nil, count: 16)
    
    // MARK: - UI Mode State
    
    /// Tracks how many pads are currently being held down to play audio.
    var playingPadsCount: Int = 0
    
    /// Computed property indicating if any audio is actively being triggered by the user.
    var isPlaying: Bool { playingPadsCount > 0 }
    
    /// When true, tapping a pad opens its configuration sheet instead of triggering audio.
    var isEditMode: Bool = false
    
    // MARK: - Sheet Navigation State
    
    /// Holds the node the user wants to trim. Triggers the WaveformEditor sheet when not nil.
    var audioClipToEdit: AudioClipViewModel? = nil
    
    /// Holds the grid index the user wants to populate. Triggers the SamplePicker sheet when not nil.
    var padToAssign: Int? = nil
    
    // MARK: - Recording State
    
    /// Locks the microphone to a specific pad index to prevent multi-touch recording bugs.
    var recordingPadIndex: Int? = nil
    
    /// Computed property indicating if the microphone is currently active.
    var isRecording: Bool { recordingPadIndex != nil }
    
    // MARK: - Dependencies
    
    /// The Conductor. Manages the global pool of saved audio data.
    let audioSampleRepoVM: AudioSampleRepositoryViewModel
    
    /// The engine responsible for triggering playback.
    let playbackService: AudioPlaybackService
    
    /// The engine responsible for capturing microphone input.
    private let recordingService: AudioRecordingService
    
    // MARK: - Initialization
    
    init(audioSampleVM: AudioSampleRepositoryViewModel,
         playbackService: AudioPlaybackService,
         recordingService: AudioRecordingService) {
        self.audioSampleRepoVM = audioSampleVM
        self.playbackService = playbackService
        self.recordingService = recordingService
    }
    
    // MARK: - Pad Interactions
    
    /// Triggered the exact millisecond the user touches a pad.
    /// Routes the touch based on the current `isEditMode` and whether the pad is empty.
    func handlePadPressed(padIndex: Int) async {
        guard padIndex >= 0 && padIndex < 16 else { return }
        let padNode = pads[padIndex]
        
        // 1. Edit Mode Intercept
        if isEditMode {
            if let node = padNode {
                // Pad has a sample -> Open the Waveform Editor
                await MainActor.run { self.audioClipToEdit = node }
            } else {
                // Pad is empty -> Open the Sample Picker
                await MainActor.run { self.padToAssign = padIndex }
            }
            return
        }
        
        // 2. Playback Route (Pad is assigned)
        if let node = padNode {
            await playbackService.play(node.sample, volume: 1.0, pan: 0.0)
            await MainActor.run { self.playingPadsCount += 1 }
        }
        // 3. Recording Route (Pad is empty)
        else {
            // Safety: Ignore touch if another pad is already recording
            if isRecording { return }
            
            // Generate a secure, unique path in the OS Temp directory
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".m4a")
            
            do {
                let started = try await recordingService.startRecording(url: tempURL)
                if started {
                    // Lock the microphone to THIS specific pad
                    await MainActor.run { self.recordingPadIndex = padIndex }
                }
            } catch {
                print("❌ Recording failed: \(error)")
            }
        }
    }
    
    /// Triggered the exact millisecond the user lifts their finger off a pad.
    /// Halts playback or validates and saves an active recording.
    func handlePadReleased(padIndex: Int) async {
        guard padIndex >= 0 && padIndex < 16 else { return }
        let padNode = pads[padIndex]
        
        // 1. Stop Playback Route
        if let node = padNode {
            await playbackService.stop(node.sample)
            await MainActor.run {
                // Safely decrement, clamping to 0 just in case of ghost touches
                self.playingPadsCount = max(0, self.playingPadsCount - 1)
            }
        }
        // 2. Stop Recording Route
        // Only process if the pad being released is the exact pad that started the recording
        else if recordingPadIndex == padIndex {
            let result = await recordingService.stopRecording()
            
            await MainActor.run {
                self.recordingPadIndex = nil // Always unlock the pad state
                
                if let validResult = result {
                    // The Duration Filter: Prevents accidental micro-taps from creating junk files.
                    if validResult.duration >= 0.5 {
                        // Hand the raw data to the Conductor, get the wrapper back, and assign it
                        let newClipNode = audioSampleRepoVM.addNewRecording(result: validResult)
                        self.pads[padIndex] = newClipNode
                    } else {
                        print("⚠️ Recording too short (\(validResult.duration)s). Discarded.")
                    }
                }
            }
        }
    }
    
    // MARK: - Arrangement Mutations
    
    /// Cleans up the grid when a sample is permanently deleted from the global pool.
    /// Iterates through all pads and removes the reference to allow ARC memory deallocation.
    @MainActor
    func handleSampleDeleted(id: UUID) {
        // 1. Tell the Conductor to delete the pure data
        audioSampleRepoVM.removeSample(id: id)
        
        // 2. Scrub your own UI grid of any dead references
        for i in 0..<16 {
            if pads[i]?.sample.id == id {
                pads[i] = nil
            }
        }
    }
    
    /// Connects a global pool sample to a specific pad on the grid.
    /// - Parameters:
    ///   - node: The active wrapper returned by the SamplePickerView.
    ///   - padIndex: The grid slot to populate.
    @MainActor
    func assignClipNode(_ node: AudioClipViewModel, toPad padIndex: Int) {
        self.pads[padIndex] = node
    }
}
