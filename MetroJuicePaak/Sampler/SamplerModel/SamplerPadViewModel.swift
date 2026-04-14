import Foundation
import SwiftUI
import Observation

@Observable
class SamplerPadViewModel {
    
    // MARK: - Core Identity
    // We hold the pure memory address, exactly as Noah's guide demands.
    let sampleID: ObjectIdentifier
    
    // MARK: - Dependencies
    // We only inject the exact slices of the repository this pad is allowed to see.
    private let repository: ReadableAudioSampleRepository & WaveformSourceAudioSampleRepository
    private let generator: WaveformGenerationService
    
    // MARK: - UI State
    // The rendered waveform. It starts as nil (empty) until generated.
    var thumbnailImage: Image? = nil
    
    // MARK: - Computed Properties (Safe Unwrapping)
    // The View reads these. If the underlying AudioSample is modified (e.g., renamed),
    // the @Observable macro notices these computed properties rely on that sample
    // and automatically triggers a UI redraw.
    
    var displayName: String {
        repository.getNamedSample(for: sampleID)?.name ?? "Empty"
    }
    
    var waveformSource: WaveformSource? {
        repository.getWaveformSource(for: sampleID)
    }
    
    // MARK: - Initialization
    
    init(sampleID: ObjectIdentifier,
         repository: ReadableAudioSampleRepository & WaveformSourceAudioSampleRepository,
         generator: WaveformGenerationService) {
        
        self.sampleID = sampleID
        self.repository = repository
        self.generator = generator
    }
    
    // MARK: - Actions
    
    /// Called by the View's .task(id:) modifier whenever the trim ratios change.
    @MainActor
    func generateThumbnail(resolution: Int) async {
        guard let source = waveformSource else { return }
        
        // The generator returns raw float data (WaveformData).
        // You will need a helper function to convert that [Float] array into a SwiftUI Image or Path.
        let rawWaveformData = await generator.generateWaveform(for: source, resolution: resolution)
        
        // Example conversion step (Implementation depends on how you draw paths):
        // self.thumbnailImage = convertDataToImage(rawWaveformData)
    }
}
