import XCTest
import AVFoundation
@testable import MetroJuicePaak

final class SamplerIntegrationTests: XCTestCase {
    
    var orchestrator: SamplerViewModel!
    var realRepository: AudioSampleRepository!
    var mockAudioService: MockAudioService!
    var mockGenerator: MockWaveformGenerator!
    var editorFactory: EditorViewModelFactory!
    
    // MARK: - Helper
    /// Creates a valid, silent WAV file to satisfy AVFoundation readers and prevent malloc crashes
    private func createDummyAudioFile() -> URL {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 44100.0, channels: 1) else { return tempURL }
        let _ = try? AVAudioFile(forWriting: tempURL, settings: format.settings)
        return tempURL
    }
    
    @MainActor
    override func setUp() async throws {
        try await super.setUp()
        
        realRepository = AudioSampleRepository()
        mockAudioService = try await MockAudioService()
        mockGenerator = MockWaveformGenerator()
        
        let realRegistry = EffectRegistry()
        
        editorFactory = EditorViewModelFactory(
            repository: realRepository,
            audioService: mockAudioService,
            waveformGenerator: mockGenerator,
            effectRegistry: realRegistry
        )
        
        orchestrator = SamplerViewModel(
            repository: realRepository,
            audioService: mockAudioService,
            editorFactory: editorFactory,
            padViewModelGenerator: mockGenerator
        )
    }
    
    @MainActor
    func testRecordingToPadFlow() async throws {
        // 1. Initial State: Repository should be completely empty
        XCTAssertEqual(realRepository.allSamples.count, 0)
        XCTAssertNil(orchestrator.padAssignments[0], "Pad 0 should be empty")
        
        // 2. Simulate User Pressing & Holding the pad
        await orchestrator.startRecording(on: 0)
        XCTAssertEqual(orchestrator.isRecordingPadIndex, 0, "Orchestrator must track which pad is currently recording")
        XCTAssertTrue(mockAudioService.isRecording, "Mock audio service must be actively recording")
        
        // 3. Simulate User Releasing the pad
        await orchestrator.stopRecording(on: 0)
        
        // 4. Assert Integration Success
        XCTAssertEqual(realRepository.allSamples.count, 1, "Real repository must successfully ingest the new recording")
        XCTAssertNotNil(orchestrator.padAssignments[0], "Orchestrator must successfully map the new repository ID to Pad 0")
        XCTAssertFalse(mockAudioService.isRecording, "Audio service must be shut off")
        XCTAssertNil(orchestrator.isRecordingPadIndex, "Orchestrator must clear the recording pad index")
    }
    
    @MainActor
    func testEditorToPadThumbnailIntegration() async throws {
        // 1. Setup: Create a sample, assign it, and generate the pad's UI state
        let sampleID = realRepository.addSample(url: createDummyAudioFile())
        orchestrator.assignSample(sampleID, toPad: 1)
        
        // Fetch the Pad ViewModel using XCTUnwrap for safety
        let padVM = try XCTUnwrap(orchestrator.getViewModel(for: 1))
        
        // Verify initial domain state
        let initialDomainSample = try XCTUnwrap(realRepository.getWaveformSource(for: sampleID))
        XCTAssertEqual(initialDomainSample.startTimeRatio, 0.0)
        
        // 3. Simulate Opening Editor and Making Edits
        // We use the orchestrator to generate the editor, testing the new factory integration!
        let editorVM = try XCTUnwrap(orchestrator.getEditorViewModel(for: sampleID))
        
        // User drags slider to 0.4 and saves
        editorVM.tempStartRatio = 0.4
        editorVM.saveEdits()
        
        // 4. Assert Integration Success
        let updatedDomainSample = try XCTUnwrap(realRepository.getWaveformSource(for: padVM.sampleID))
        XCTAssertEqual(updatedDomainSample.startTimeRatio, 0.4, "The Pad must instantly reflect the trim changes saved by the Editor via the shared Repository")
    }
}
