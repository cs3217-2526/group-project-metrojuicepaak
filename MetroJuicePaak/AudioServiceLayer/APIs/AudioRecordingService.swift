//
//  AudioRecordingService.swift
//  MetroJuicePaak
//
//  Created by Noah Ang Shi Hern on 3/4/26.
//

import Foundation

/// Recording quality presets
enum RecordingQuality {
    case high
    case medium
    case low
}

/// Configuration for audio recording
/// Framework-agnostic settings that AudioService converts to AVFoundation format
struct RecordingSettings {
    let quality: RecordingQuality
    let sampleRate: Double
    let numberOfChannels: Int
    
    /// Default high-quality stereo recording at 44.1kHz
    static let `default` = RecordingSettings(
        quality: .high,
        sampleRate: 44100.0,
        numberOfChannels: 2
    )
    
    /// Compressed mono recording at 22.05kHz for smaller file sizes
    static let compressed = RecordingSettings(
        quality: .medium,
        sampleRate: 22050.0,
        numberOfChannels: 1
    )
    
    /// Low-quality mono recording at 16kHz for minimal storage
    static let lowQuality = RecordingSettings(
        quality: .low,
        sampleRate: 16000.0,
        numberOfChannels: 1
    )
}

// ─────────────────────────────────────────
// MARK: - Service Protocol
// ─────────────────────────────────────────

/// Protocol for audio recording operations
protocol AudioRecordingService {
    
    /// Starts recording audio from the device microphone
    /// - Parameter settings: Optional recording settings (defaults to .default if nil)
    /// - Throws: If recording permission is denied or audio session fails
    /// - Returns: true if recording started successfully
    func startRecording(settings: RecordingSettings?) async throws -> Bool // not sure if this should also take in a url
    
    func startRecording(url: URL) async throws -> Bool //temp declaration to test out url-based recording
    
    /// Stops the current recording session
    /// - Returns: RecordingResult containing the file URL and duration, or nil if no recording was active
    func stopRecording() async -> RecordingResult?
    
    /// Checks if currently recording
    var isRecording: Bool { get }
    
    /// Current recording duration (updates in real-time)
    var recordingDuration: TimeInterval { get }
}
