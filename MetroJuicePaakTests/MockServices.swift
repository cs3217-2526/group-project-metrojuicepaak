import Foundation


// MARK: - Lightweight Mocks for Testing
#if DEBUG
final class MockAudioService: AudioServiceProtocol {
    var lastPlayedSample: PlayableAudioSample?
    var stopCalled = false
    
    func play(_ sample: PlayableAudioSample) async {
        lastPlayedSample = sample
    }
    func playOverlapping(_ sample: PlayableAudioSample) async {
        lastPlayedSample = sample
    }
    func stop(_ sample: PlayableAudioSample) async {
        stopCalled = true
    }
    func stopAll() async {
        stopCalled = true
    }
    func load(sample: PlayableAudioSample, polyphony: Int) async throws {}
    func unload(_ sample: PlayableAudioSample) async {}
    
    // MARK: - AudioRecordingService Conformance
    
    var isRecording: Bool = false
    var recordingDuration: TimeInterval = 0.0
    
    func startRecording(settings: RecordingSettings?) async throws -> Bool {
        isRecording = true
        return true
    }
    
    func startRecording(url: URL) async throws -> Bool {
        isRecording = true
        return true
    }
    
    func stopRecording() async -> RecordingResult? {
        isRecording = false
        // Return a dummy URL and duration for the tests
        return RecordingResult(url: URL(fileURLWithPath: "/test/path.m4a"), duration: 1.0)
    }
    // MARK: - AudioConfigurationService Conformance
        
    var masterVolume: Float = 1.0
    var isDuckingEnabled: Bool = false
    var configurationCalled: Bool = false
    
    func configureAudioSession() throws {
        // Just record that it was called, no actual hardware configuration needed
        configurationCalled = true
    }
    
    func setMasterVolume(_ volume: Float) {
        self.masterVolume = volume
    }
    
    func setDuckingEnabled(_ enabled: Bool) {
        self.isDuckingEnabled = enabled
    }
    // MARK: - AudioPlaybackService  Conformance
        
    // A dummy host time for testing the sequencer logic
    var currentHostTime: TimeInterval {
        return Date().timeIntervalSince1970
    }
    
    func scheduleAt(_ sample: PlayableAudioSample, time: TimeInterval) {
        // Record that it was scheduled so we can assert it in our tests
        self.lastPlayedSample = sample
    }
    
    func isLoaded(_ sample: PlayableAudioSample) -> Bool {
        // For our unit tests, we'll assume samples are successfully loaded
        return true
    }
    
    func isPlaying(_ sample: PlayableAudioSample) -> Bool {
        // Simple dummy logic: it's playing if it was the last thing played and stop wasn't called
        return lastPlayedSample?.url == sample.url && !stopCalled
    }
}

class MockWaveformGenerator: WaveformGenerationService {
    
    func generateWaveform(for source: WaveformSource, resolution: Int) async -> WaveformData {
        // 1. Generate an array of dummy floats
        let dummyAmplitudes: [Float] = (0..<resolution).map { index in
            let progress = Float(index) / Float(resolution)
            return abs(sin(progress * .pi * 6))
        }
        
        // 2. Return the struct using the correct 'points' parameter
        return WaveformData(points: dummyAmplitudes)
    }
}

#endif
