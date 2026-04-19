import XCTest
import AVFoundation
@testable import MetroJuicePaak

final class SamplerIntegrationTests: XCTestCase {
    
    var orchestrator: SamplerViewModel!
    var realRepository: AudioSampleRepository!
    var mockAudioService: MockAudioService!
    var mockGenerator: MockWaveformGenerator!
    var editorFactory: EditorViewModelFactory!
    var padFactory: PadViewModelFactory!
    
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
        padFactory = PadViewModelFactory(
            repository: realRepository,
            waveformService: mockGenerator
        )
        
        orchestrator = SamplerViewModel(
            repository: realRepository,
            audioService: mockAudioService,
            editorFactory: editorFactory,
            padFactory: padFactory
        )
    }
    
    @MainActor
    func testRecordingToPadFlow() async throws {
        XCTAssertEqual(realRepository.allSamples.count, 0)
        XCTAssertNil(orchestrator.padAssignments[0], "Pad 0 should be empty")
        
        await orchestrator.startRecording(on: 0)
        XCTAssertEqual(orchestrator.isRecordingPadIndex, 0, "Orchestrator must track which pad is currently recording")
        XCTAssertTrue(mockAudioService.isRecording, "Mock audio service must be actively recording")
        
        await orchestrator.stopRecording(on: 0)
        
        XCTAssertEqual(realRepository.allSamples.count, 1, "Real repository must successfully ingest the new recording")
        XCTAssertNotNil(orchestrator.padAssignments[0], "Orchestrator must successfully map the new repository ID to Pad 0")
        XCTAssertFalse(mockAudioService.isRecording, "Audio service must be shut off")
        XCTAssertNil(orchestrator.isRecordingPadIndex, "Orchestrator must clear the recording pad index")
    }
    
    @MainActor
    func testEditorToPadThumbnailIntegration() async throws {
        let sampleID = realRepository.addSample(url: createDummyAudioFile())
        orchestrator.assignSample(sampleID, toPad: 1)
        
        let padVM = try XCTUnwrap(orchestrator.getViewModel(for: 1))
        
        let initialDomainSample = try XCTUnwrap(realRepository.getWaveformSource(for: sampleID))
        XCTAssertEqual(initialDomainSample.startTimeRatio, 0.0)
        
        let editorVM = try XCTUnwrap(orchestrator.getEditorViewModel(for: sampleID))
        
        editorVM.tempStartRatio = 0.4
        editorVM.saveEdits()
        
        let updatedDomainSample = try XCTUnwrap(realRepository.getWaveformSource(for: padVM.sampleID))
        XCTAssertEqual(updatedDomainSample.startTimeRatio, 0.4, "The Pad must instantly reflect the trim changes saved by the Editor via the shared Repository")
    }
}

