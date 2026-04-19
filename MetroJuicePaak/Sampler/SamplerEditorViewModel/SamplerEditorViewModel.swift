import Foundation
import Observation

/// Manages the transient state and business logic for the Waveform Editor modal.
///
/// Fix this documentation 
@Observable
class SamplerEditorViewModel {
    
    /// The unique memory address of the audio sample being edited.
    let sampleID: ObjectIdentifier
    
    // MARK: - Narrow Protocol Views
    
    /// The mutable view of the sample used to commit trim ratio changes.
    private let editable: EditableAudioSample
    
    /// The read-only metadata view of the sample used as a baseline for generation and backups.
    let waveformSource: WaveformSource
    
    /// The read-only playback view of the sample passed to the audio engine for previewing.
    private let playable: PlayableAudioSample
    
    /// The engine responsible for routing preview audio to the device hardware.
    private let audioService: AudioServiceProtocol
    
    /// The math engine responsible for decoding audio frames into visual amplitude data.
    private let generator: WaveformGenerationService

    // MARK: - Temporary UI State
    
    /// The temporary starting trim position, represented as a normalized ratio (0.0 to 1.0).
    /// - Note: The SwiftUI UI binds exclusively to this property to prevent premature domain mutations.
    var tempStartRatio: Double
    
    /// The temporary ending trim position, represented as a normalized ratio (0.0 to 1.0).
    /// - Note: The SwiftUI UI binds exclusively to this property to prevent premature domain mutations.
    var tempEndRatio: Double
    
    /// The normalized amplitude data used by the UI to draw the audio waveform.
    var waveformData: WaveformData? = nil
    
    /// Tracks whether the preview audio is currently playing to update UI toggle states.
    var isPlayingPreview: Bool = false
    
    // MARK: - Safety Backups
    
    /// The original start ratio captured the moment the editor was opened. Used to revert changes on cancellation.
    private let originalStartRatio: Double
    
    /// The original end ratio captured the moment the editor was opened. Used to revert changes on cancellation.
    private let originalEndRatio: Double
    
    // MARK: - Initialization
    
    /// Initializes the editor sandbox and extracts the necessary protocol views.
    ///
    /// - Parameters:
    ///   - sampleID: The identifier of the sample to edit.
    ///   - repository: The central vault used to extract the `Editable`, `Playable`, and `WaveformSource` views.
    ///   - audioService: The service used to play the preview audio.
    ///   - generator: The service used to render the high-resolution waveform.
    /// - Returns: `nil` if the sample no longer exists or if the repository cannot resolve all required views.
    init?(sampleID: ObjectIdentifier,
          repository: ReadableAudioSampleRepository & EditableAudioSampleRepository & WaveformSourceAudioSampleRepository &
              EffectableAudioSampleRepository,
          audioService: AudioServiceProtocol,
          generator: WaveformGenerationService) {
        
        guard let editable = repository.getEditableSample(for: sampleID),
              let waveformSource = repository.getWaveformSource(for: sampleID),
              let playable = repository.getPlayableSample(for: sampleID) else {
            return nil
        }
    
        self.sampleID = sampleID
        self.editable = editable
        self.waveformSource = waveformSource
        self.playable = playable
        self.audioService = audioService
        self.generator = generator
        
        // Save the real values as backups
        self.originalStartRatio = waveformSource.startTimeRatio
        self.originalEndRatio = waveformSource.endTimeRatio
        
        // Initialize the sliders to match the real values
        self.tempStartRatio = waveformSource.startTimeRatio
        self.tempEndRatio = waveformSource.endTimeRatio
    }
    
    // MARK: - The Generator
    
    /// A localized, private wrapper that forces the waveform cache to read 100% of the audio file.
    ///
    /// By hardcoding the ratios to 0.0 and 1.0, this struct tricks the `WaveformGenerationService`
    /// into generating the full, untrimmed audio shape. This allows the user to see the entire
    /// sound wave and drag the dark overlay sliders across it accurately.
    private struct FullWaveformSource: WaveformSource {
        let url: URL
        let startTimeRatio: Double = 0.0
        let endTimeRatio: Double = 1.0
    }
    
    /// Asynchronously generates the high-resolution visual representation of the entire audio file.
    /// - Parameter resolution: The number of data points (buckets) to generate, typically matching the UI width.
    @MainActor
    func generateThumbnail(resolution: Int) async {
        // Wrap the actual URL in our fake untrimmed source
        let untrimmedSource = FullWaveformSource(url: waveformSource.url)
        
        // Ask the cache to generate the visual using the untrimmed source
        self.waveformData = await generator.generateWaveform(for: untrimmedSource, resolution: resolution)
    }
    
    // MARK: - SwiftUI Bindings (The Safe Bridge)
    
    /// A direct bridge to the domain model's start trim ratio.
    /// - Note: Safely catches and ignores invalid domain states (e.g., crossing the end marker)
    ///         thrown by continuous UI drag gestures.
    var startRatio: Double {
        get { waveformSource.startTimeRatio }
        set {
            do {
                try editable.setStartTimeRatio(newValue)
            } catch {
                print("Trim validation failed: \(error.localizedDescription)")
            }
        }
    }
    
    /// A direct bridge to the domain model's end trim ratio.
    /// - Note: Safely catches and ignores invalid domain states thrown by continuous UI drag gestures.
    var endRatio: Double {
        get { waveformSource.endTimeRatio }
        set {
            do {
                try editable.setEndTimeRatio(newValue)
            } catch {
                print("Trim validation failed: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Actions
    
    /// Toggles the playback of the audio sample using the current temporary trim ratios.
    ///
    /// - Note: To allow the engine to play the exact segment the user is viewing, this method
    ///         temporarily pushes the transient slider values down to the domain model before
    ///         calling `play`.
    @ObservationIgnored private var previewGeneration: Int = 0

    func togglePreview() async {
        if isPlayingPreview {
            await audioService.stop(playable)
            isPlayingPreview = false
        } else {
            do {
                try editable.setStartTimeRatio(tempStartRatio)
                try editable.setEndTimeRatio(tempEndRatio)
            } catch {
                print("Failed to apply preview trim: \(error)")
                return
            }

            previewGeneration += 1
            let thisGeneration = previewGeneration
            isPlayingPreview = true

            await audioService.play(playable) { [weak self] in
                guard let self, self.previewGeneration == thisGeneration else { return }
                self.isPlayingPreview = false
            }
        }
    }
    
    /// Halts playback and permanently commits the transient slider edits to the domain model.
    func saveEdits() {
        Task { await audioService.stop(playable) }
        
        try? editable.setStartTimeRatio(tempStartRatio)
        try? editable.setEndTimeRatio(tempEndRatio)
    }
    
    /// Halts playback and reverts the domain model to the original backup values captured at initialization.
    func cancelEdits() {
        Task { await audioService.stop(playable) }
        
        try? editable.setStartTimeRatio(originalStartRatio)
        try? editable.setEndTimeRatio(originalEndRatio)
    }
    
    /// Instantly halts audio playback. Safe to call rapidly during continuous slider drag gestures.
    func stopPreview() {
        if isPlayingPreview {
            Task { await audioService.stop(playable) }
            isPlayingPreview = false
        }
    }
}
