import Foundation
import Observation

/// Identifiable wrapper for triggering the Waveform Editor modal.
struct EditContext: Identifiable {
    let id: ObjectIdentifier
}

/// Identifiable wrapper for triggering the Sample Picker modal.
struct PickerContext: Identifiable {
    let id: Int
}

/// The central orchestrator for the MetroJuicePaak drum machine.
///
/// `SamplerViewModel` sits between the UI layer (the pad grid) and the domain/service layers.
/// It strictly adheres to Clean Architecture by restricting its own access via `SamplerRepositoryProtocols`
/// and by mapping physical UI slots to `ObjectIdentifier`s rather than concrete domain models.
@Observable
class SamplerViewModel {
    
    // MARK: - Dependencies
    
    /// A typealias restricting this ViewModel to only the repository capabilities it strictly needs.
    typealias SamplerRepositoryProtocols = WritableAudioSampleRepository & ReadableAudioSampleRepository & WaveformSourceAudioSampleRepository & EditableAudioSampleRepository
    
    let repository: SamplerRepositoryProtocols
    private let audioService: AudioServiceProtocol
    private let waveformGenerator: WaveformGenerationService
    
    // MARK: - Core State
    
    /// The master ledger mapping a physical pad index (0-15) to a sample's unique memory address.
    /// - Note: We do not store concrete `AudioSample` references here to prevent accidental domain mutations.
    var padAssignments: [Int: ObjectIdentifier] = [:]
    
    /// Tracks which pad is currently capturing microphone input.
    /// Used by the UI to render recording indicators (e.g., a red highlight).
    var isRecordingPadIndex: Int? = nil
    
    /// A localized cache of child ViewModels to prevent unnecessary re-allocations during UI redraws.
    /// - Note: Marked with `@ObservationIgnored` to prevent infinite rendering loops when SwiftUI
    ///         queries the factory method during a view update.
    @ObservationIgnored
    private var padViewModelCache: [Int: SamplerPadViewModel] = [:]
    
    // MARK: - Global Interaction State
    
    /// Determines how pad interactions are interpreted by the gesture router.
    /// - `true`: Interactions open configuration menus (Editor/Picker).
    /// - `false`: Interactions trigger audio playback.
    /// - Note: Entering Edit Mode instantly halts all active audio playback to prevent sonic clutter.
    var isEditMode: Bool = false {
        didSet {
            if isEditMode {
                Task { await audioService.stopAll() }
            }
        }
    }
    
    // MARK: - Navigation State
    
    /// The `ObjectIdentifier` of the sample currently selected for editing.
    /// Binding this to a SwiftUI `.sheet` triggers the Waveform Editor modal.
    var sampleIDToEdit: EditContext? = nil
    
    /// The index of the empty pad currently awaiting a sample assignment.
    /// Binding this to a SwiftUI `.sheet` triggers the Sample picker modal.
    var padIndexAwaitingAssignment: PickerContext? = nil
    
    // MARK: - Initialization
    
    /// Initializes the orchestrator with strict boundaries.
    /// - Parameters:
    ///   - repository: The central vault managing sample lifecycles and identities.
    ///   - audioService: The hardware bridge for routing audio to the engine.
    ///   - waveformGenerator: The math engine for rendering visuals.
    init(repository: SamplerRepositoryProtocols,
         audioService: AudioServiceProtocol,
         waveformGenerator: WaveformGenerationService) {
        self.repository = repository
        self.audioService = audioService
        self.waveformGenerator = waveformGenerator
    }
    
    // MARK: - Pad UI Factory
    
    /// Generates a lightweight, read-only ViewModel for a specific pad.
    ///
    /// This factory method keeps the SwiftUI layer completely ignorant of domain logic,
    /// while utilizing an internal cache to protect state during high-frequency UI redraws.
    ///
    /// - Parameter padIndex: The physical slot number (0-15).
    /// - Returns: A `SamplerPadViewModel` if a sample is assigned, otherwise `nil`.
    func getViewModel(for padIndex: Int) -> SamplerPadViewModel? {
        // If the pad is empty, remove it from the cache
        guard let sampleID = padAssignments[padIndex] else {
            padViewModelCache.removeValue(forKey: padIndex)
            return nil
        }
        
        // If we already built a ViewModel for this exact sample, return it instantly
        if let existingVM = padViewModelCache[padIndex], existingVM.sampleID == sampleID {
            return existingVM
        }
        
        // Otherwise, build a new one, cache it, and return it
        let newVM = SamplerPadViewModel(
            sampleID: sampleID,
            repository: repository,
            generator: waveformGenerator
        )
        padViewModelCache[padIndex] = newVM
        return newVM
    }
    
    // MARK: - Editor UI Factory
        
    /// Creates a specialized ViewModel for the Waveform Editor.
    ///
    /// - Parameter sampleID: The unique identifier of the sample to edit.
    /// - Returns: A `WaveformEditorViewModel` if the sample exists, otherwise `nil`.
    func getEditorViewModel(for sampleID: ObjectIdentifier) -> WaveformEditorViewModel? {
        return WaveformEditorViewModel(
            sampleID: sampleID,
            repository: repository,
            audioService: audioService,
            generator: waveformGenerator
        )
    }
    
    // MARK: - Interaction Routing
    
    /// The central router for tap gestures initiated by the UI.
    ///
    /// Evaluates the global `isEditMode` state to determine whether to trigger audio playback
    /// or update navigation state variables to present modal sheets.
    ///
    /// - Parameter padIndex: The physical slot number (0-15) that was tapped.
    func handlePadTap(padIndex: Int) {
        if isEditMode {
            if let assignedID = padAssignments[padIndex] {
                sampleIDToEdit = EditContext(id: assignedID)
            } else {
                padIndexAwaitingAssignment = PickerContext(id: padIndex)
            }
        } else {
            Task { await playPad(padIndex: padIndex) }
        }
    }
    
    // MARK: - Playback Flow
    
    /// Fetches the read-only playback view of a sample and triggers overlapping playback.
    ///
    /// - Parameter padIndex: The physical slot number (0-15).
    func playPad(padIndex: Int) async {
        guard let sampleID = padAssignments[padIndex],
              let playableSample = repository.getPlayableSample(for: sampleID) else { return }
        
        await audioService.playOverlapping(playableSample)
    }
    
    // MARK: - Recording Flow
    
    /// Initiates hardware microphone capture for the specified pad.
    /// - Parameter padIndex: The physical slot number (0-15) being held.
    func startRecording(on padIndex: Int) async {
        guard !audioService.isRecording else { return }
        
        do {
            let started = try await audioService.startRecording(settings: nil)
            if started {
                isRecordingPadIndex = padIndex
            }
        } catch {
            print("Failed to start recording: \(error.localizedDescription)")
        }
    }
    
    /// Halts hardware microphone capture, saves the file to the repository, and assigns it to the pad.
    ///
    /// - Note: Sample creation is strictly delegated to the repository via `addSample(url:)`.
    ///         The resulting sample is immediately loaded into the audio engine with polyphony allocated.
    /// - Parameter padIndex: The physical slot number (0-15) that was released.
    func stopRecording(on padIndex: Int) async {
        isRecordingPadIndex = nil
        
        guard let result = await audioService.stopRecording() else { return }
        
        let newSampleID = repository.addSample(url: result.url)
        padAssignments[padIndex] = newSampleID
        
        if let playableSample = repository.getPlayableSample(for: newSampleID) {
            do {
                // Pre-allocate 6 voices to allow rapid drum rolls (machine-gun effect) on this newly recorded sample
                try await audioService.load(sample: playableSample, polyphony: 6)
            } catch {
                print("Failed to load sample into engine: \(error)")
            }
        }
    }
    
    // MARK: - Sample Management // clarify behavior
    
    /// Unassigns a sample from a pad and performs proactive garbage collection.
    ///
    /// If the unassigned sample is no longer referenced by any other pad in the grid,
    /// it is unloaded from the audio engine's RAM and permanently removed from the repository.
    ///
    /// - Parameter padIndex: The physical slot number (0-15) to clear.
//    func clearPad(padIndex: Int) async {
//        guard let sampleID = padAssignments.removeValue(forKey: padIndex) else { return }
//        
//        let isUsedElsewhere = padAssignments.values.contains(sampleID)
//        
//        if !isUsedElsewhere {
//            if let playableSample = repository.getPlayableSample(for: sampleID) {
//                await audioService.unload(playableSample)
//            }
//            repository.removeSample(id: sampleID)
//        }
//    }
    
    // MARK: - Helper Methods
        
    /// Assigns an existing repository sample to a pad and loads it into memory.
    /// - Parameters:
    ///   - sampleID: The unique identifier of the selected sample.
    ///   - padIndex: The target physical slot number (0-15).
    func assignSample(_ sampleID: ObjectIdentifier, toPad padIndex: Int) {
        // Update the ledger instantly for a responsive UI
        padAssignments[padIndex] = sampleID
        
        // Spin up a background thread for the heavy file I/O
        Task {
            if let playable = repository.getPlayableSample(for: sampleID) {
                do {
                    try await audioService.load(sample: playable, polyphony: 6)
                } catch {
                    print("Failed to load picked sample: \(error.localizedDescription)")
                }
            }
        }
    }
}
