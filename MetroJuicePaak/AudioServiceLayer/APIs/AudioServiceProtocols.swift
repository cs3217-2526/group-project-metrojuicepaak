//
//  AudioServiceProtocols.swift
//  MetroJuicePaak
//
//  Created by Noah Ang Shi Hern on 3/4/26.
//

import Foundation

/// Combined protocol that AudioService should conform to
/// This provides the complete audio engine API
protocol AudioServiceProtocol:
    AudioPlaybackService,
    AudioRecordingService,
    AudioConfigurationService {
    
    /// Initializes the audio service
    /// - Throws: If initialization fails
    init() async throws
}

// ─────────────────────────────────────────
// MARK: - Default Parameter Extensions
// ─────────────────────────────────────────

extension AudioPlaybackService {
    
    /// Plays a sample with default volume and pan
    func play(_ sample: AudioSample) async {
        await play(sample, volume: 1.0, pan: 0.0)
    }
    
    /// Plays a sample with custom volume
    func play(_ sample: AudioSample, volume: Float) async {
        await play(sample, volume: volume, pan: 0.0)
    }
}

extension AudioRecordingService {
    
    /// Starts recording with default settings
    func startRecording() async throws -> Bool {
        try await startRecording(settings: nil)
    }
}

extension WaveformGenerationService {
    
    /// Generates full waveform (0.0 to 1.0 range)
    func generateWaveform(for sample: AudioSample, resolution: Int) async -> [Float] {
        await generateWaveform(
            for: sample,
            resolution: resolution,
        )
    }
}
