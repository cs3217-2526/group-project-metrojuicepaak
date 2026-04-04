//
//  MockServices.swift
//  MetroJuicePaak
//
//  TEMPORARY FILE: Delete when AudioServiceLayer is complete
//

import Foundation

// MARK: - Fake Playback Service
class MockAudioPlaybackService: AudioPlaybackService {
    
    func load(_ sample: AudioSample) async throws {
        print("💿 [MOCK] Loaded sample: \(sample.name)")
    }
    
    func unload(_ sample: AudioSample) async {
        print("⏏️ [MOCK] Unloaded sample: \(sample.name)")
    }
    
    func play(_ sample: AudioSample, volume: Float, pan: Float) async {
        print("🎧 [MOCK] Playing audio: \(sample.name) (Vol: \(volume), Pan: \(pan))")
    }
    
    func stop(_ sample: AudioSample) async {
        print("⏹️ [MOCK] Stopped audio: \(sample.name)")
    }
    
    func stopAll() async {
        print("⏹️ [MOCK] Stopped ALL audio")
    }
    
    func isLoaded(_ sample: AudioSample) -> Bool {
        return true
    }
    
    func isPlaying(_ sample: AudioSample) -> Bool {
        return false
    }
}

// MARK: - Fake Recording Service
class MockAudioRecordingService: AudioRecordingService {
    
    var isRecording: Bool = false
    var recordingDuration: TimeInterval = 0.0
    
    func startRecording(settings: RecordingSettings?) async throws -> Bool {
        print("🔴 [MOCK] Started recording (Settings: \(String(describing: settings?.quality)))")
        self.isRecording = true
        return true
    }
    
    func startRecording(url: URL) async throws -> Bool {
        print("🔴 [MOCK] Started recording to specific URL: \(url.lastPathComponent)")
        self.isRecording = true
        return true
    }
    
    func stopRecording() async -> RecordingResult? {
        print("⬛️ [MOCK] Stopped recording.")
        self.isRecording = false
        
        // Create a fake temporary URL to satisfy your teammate's RecordingResult struct
        let mockURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".m4a")
        
        // Simulating a successful 1.5 second recording
        return RecordingResult(
            url: mockURL,
            duration: 1.5
        )
    }
}

// MARK: - Fake Waveform Generator
class MockWaveformGenerator: WaveformGenerationService {
    
    func generateWaveform(for sample: AudioSample, resolution: Int) async -> WaveformData {
        print("📊 [MOCK] Generating waveform array of \(resolution) points for: \(sample.name)")
        
        // Create the array of floats, then wrap it in the WaveformData struct
        let mockPoints = Array(repeating: Float(0.1), count: resolution)
        return WaveformData(points: mockPoints)
    }
}
