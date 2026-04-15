import Foundation
import SwiftUI
import Observation

/// A lightweight, localized ViewModel representing a single physical pad on the 4x4 grid.
///
/// `SamplerPadViewModel` acts as the read-only visual state for a single assigned sample.
/// It is completely decoupled from playback and recording logic (which are handled by the
/// central `SamplerViewModel` orchestrator). Its sole responsibility is to fetch display metadata
/// and manage the asynchronous generation of the pad's waveform thumbnail.
@Observable
class SamplerPadViewModel {
    
    // MARK: - Identity & Dependencies
    
    /// The unique memory address of the underlying audio sample in the repository.
    /// Used to query the latest data without holding a strong reference to the domain model itself.
    let sampleID: ObjectIdentifier
    
    /// A segregated view of the repository, restricted to reading display names and waveform parameters.
    private let repository: ReadableAudioSampleRepository & WaveformSourceAudioSampleRepository
    
    /// The math engine (typically a `WaveformCache` actor) responsible for crunching audio frames into visual data.
    private let generator: WaveformGenerationService
    
    // MARK: - Render State
    
    /// The normalized amplitude data used by the UI to draw the audio waveform.
    ///
    /// - Note: This starts as `nil`. Because this class is `@Observable`, assigning the completed
    ///         data to this variable after the background decode finishes will instantly trigger
    ///         the SwiftUI `SamplerPadButton` to redraw.
    var waveformData: WaveformData? = nil
    
    // MARK: - Computed Properties
    
    /// The human-readable name of the sample, fetched live from the repository.
    /// Defaults to "Empty" if the sample was unexpectedly removed from the repository.
    var displayName: String {
        repository.getNamedSample(for: sampleID)?.name ?? "Empty"
    }
    
    /// The specific data slice needed by the generator to build the visual waveform.
    /// Includes the file URL and the current start/end trim ratios.
    var waveformSource: WaveformSource? {
        repository.getWaveformSource(for: sampleID)
    }
    
    // MARK: - Initialization
    
    /// Creates a localized ViewModel for a specific sample.
    /// - Parameters:
    ///   - sampleID: The unique identifier of the sample this pad represents.
    ///   - repository: The central vault for fetching current sample data.
    ///   - generator: The service used to generate the waveform visuals.
    init(sampleID: ObjectIdentifier,
         repository: ReadableAudioSampleRepository & WaveformSourceAudioSampleRepository,
         generator: WaveformGenerationService) {
        self.sampleID = sampleID
        self.repository = repository
        self.generator = generator
    }
    
    // MARK: - Actions
    
    /// Asynchronously generates the high-resolution visual representation of the audio sample.
    ///
    /// This method offloads the heavy file decoding and amplitude bucketing to the `WaveformGenerationService`
    /// (preventing main-thread stutters) and safely applies the result back to the UI thread.
    ///
    /// - Parameter resolution: The number of data points (buckets) to generate, typically matching the physical width of the UI view.
    @MainActor
    func generateThumbnail(resolution: Int) async {
        guard let source = waveformSource else { return }
        
        let generatedData = await generator.generateWaveform(for: source, resolution: resolution)
        
        self.waveformData = generatedData
    }
}
