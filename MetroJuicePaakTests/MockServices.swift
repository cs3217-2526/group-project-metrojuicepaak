import Foundation

#if DEBUG

// MARK: - Missing Registry Mock for Tests
class MockEffectRegistry: EffectRegistry {
    override func make(identifier: String) -> DSPEffect? {
        return nil // Tests don't need real DSP math
    }
}

// MARK: - Fully Conforming Audio Service Mock
final class MockAudioService: AudioServiceProtocol, LiveEffectChainService {
    
    // Test Assertion Variables
    var lastPlayedSample: PlayableAudioSample?
    var stopCalled = false
    
    // Required Async Initializer
    required init() async throws {}
    
    // MARK: - AudioPlaybackService
    var currentHostTime: TimeInterval { return Date().timeIntervalSince1970 }
 
    func play(_ sample: PlayableAudioSample,
              onCompletion: (@Sendable @MainActor () -> Void)? = nil) async {
        lastPlayedSample = sample
    }
    func playOverlapping(_ sample: PlayableAudioSample,
                         onCompletion: (@Sendable @MainActor () -> Void)? = nil) async {
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
    
    func isLoaded(_ sample: PlayableAudioSample) -> Bool { return true }
    func isPlaying(_ sample: PlayableAudioSample) -> Bool {
        return lastPlayedSample?.url == sample.url && !stopCalled
    }
    
    // MARK: - AudioRecordingService
    var isRecording: Bool = false
    var recordingDuration: TimeInterval = 0.0
    
    func startRecording(settings: RecordingSettings?) async throws -> Bool {
        isRecording = true; return true
    }
    func startRecording(url: URL) async throws -> Bool {
        isRecording = true; return true
    }
    func stopRecording() async -> RecordingResult? {
        isRecording = false
        return RecordingResult(url: URL(fileURLWithPath: "/test.m4a"), duration: 1.0)
    }
    
    // MARK: - AudioConfigurationService
    var masterVolume: Float = 1.0
    var isDuckingEnabled: Bool = false
    
    func configureAudioSession() throws {}
    func setMasterVolume(_ volume: Float) { self.masterVolume = volume }
    func setDuckingEnabled(_ enabled: Bool) { self.isDuckingEnabled = enabled }
    
    // MARK: - AudioPlaybackService  Conformance
        
    func scheduleAt(_ sample: PlayableAudioSample, time: TimeInterval,
                    onCompletion: (@Sendable @MainActor () -> Void)? = nil) {
        // Record that it was scheduled so we can assert it in our tests
        self.lastPlayedSample = sample
    }
    
    func rebuildEffectChain(for sample: EffectableAudioSample) async throws {
        return
    }

    /// Routes a single parameter change to the live effect on the audio thread.
    /// The three value arguments remain because they describe a specific atomic
    /// change that isn't derivable from the sample's state — this is the LIVE
    /// path, not the descriptor path.
    func updateEffectParameter(
        for sample: EffectableAudioSample,
        effectInstanceId: UUID,
        parameterId: String,
        value: Float
    ) {
        return
    }
}

// MARK: - Waveform Mock
class MockWaveformGenerator: WaveformGenerationService {
    func generateWaveform(for source: WaveformSource, resolution: Int) async -> WaveformData {
        let dummyAmplitudes: [Float] = (0..<resolution).map { index in
            let progress = Float(index) / Float(resolution)
            return abs(sin(progress * .pi * 6))
        }
        return WaveformData(points: dummyAmplitudes)
    }
}
#endif
