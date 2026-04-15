//
//  MockServices.swift
//  MetroJuicePaak
//
//  TEMPORARY FILE: Delete when AudioServiceLayer is complete
//

import Foundation

// MARK: - Fake Playback Service
class MockAudioPlaybackService: AudioPlaybackService {
    
    func load(sample: PlayableAudioSample, polyphony: Int) async throws {
        print("💿 [MOCK] Loaded sample: \(sample.url.lastPathComponent) (Polyphony: \(polyphony))")
    }
    
    func unload(_ sample: PlayableAudioSample) async {
        print("⏏️ [MOCK] Unloaded sample: \(sample.url.lastPathComponent)")
    }
    
    func play(_ sample: PlayableAudioSample) async {
        // The real AudioEngine reads volume/pan directly from the sample now!
        print("🎧 [MOCK] Playing audio: \(sample.url.lastPathComponent) (Vol: \(sample.volume), Pan: \(sample.pan))")
    }
    
    func playOverlapping(_ sample: PlayableAudioSample) async {
        print("🎧 [MOCK] Playing overlapping audio: \(sample.url.lastPathComponent)")
    }
    
    func scheduleAt(sample: PlayableAudioSample, time: TimeInterval) {
        print("⏰ [MOCK] Scheduled audio: \(sample.url.lastPathComponent) at \(time)")
    }
    
    func stop(_ sample: PlayableAudioSample) async {
        print("⏹️ [MOCK] Stopped audio: \(sample.url.lastPathComponent)")
    }
    
    func stopAll() async {
        print("⏹️ [MOCK] Stopped ALL audio")
    }
    
    func isLoaded(_ sample: PlayableAudioSample) -> Bool {
        return true
    }
    
    func isPlaying(_ sample: PlayableAudioSample) -> Bool {
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
