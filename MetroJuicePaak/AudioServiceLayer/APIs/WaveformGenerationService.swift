//
//  WaveformGenerationService.swift
//  MetroJuicePaak
//
//  Created by Noah Ang Shi Hern on 3/4/26.
//

/// Protocol for generating waveform visualizations from audio samples
protocol WaveformGenerationService {
    
    /// Generates waveform amplitude data for visualization
    /// - Parameters:
    ///   - sample: The AudioSample to analyze
    ///   - resolution: Number of data points to generate (e.g., 100 for 100 bars)
    /// - Returns: WaveformData represented by array of normalized amplitude values (0.0 to 1.0)
    func generateWaveform(
        for sample: AudioSample,
        resolution: Int
    ) async -> WaveformData
}
