import XCTest
@testable import MetroJuicePaak
final class SamplerIntegrationTests: XCTestCase {
    
    var orchestrator: SamplerViewModel!
    var realRepository: AudioSampleRepository!
    var mockAudioService: MockAudioService!
    var mockGenerator: MockWaveformGenerator!
    
    @MainActor
    override func setUp() {
        super.setUp()
        // We use the REAL repository now to test data flow!
        realRepository = AudioSampleRepository()
        mockAudioService = MockAudioService()
        mockGenerator = MockWaveformGenerator()
        
        orchestrator = SamplerViewModel(
            repository: realRepository,
            audioService: mockAudioService,
            waveformGenerator: mockGenerator
        )
    }
    
    @MainActor
    func testRecordingToPadFlow() async {
        // 1. Initial State: Repository should be completely empty
        XCTAssertEqual(realRepository.allSamples.count, 0)
        XCTAssertNil(orchestrator.padAssignments[0], "Pad 0 should be empty")
        
        // 2. Simulate User Pressing & Holding the pad
        // Note: Replace with your actual Orchestrator recording functions if named differently
        do {
            _ = try await mockAudioService.startRecording(settings: .default)
            orchestrator.isRecordingPadIndex = 0
        } catch {
            XCTFail("Failed to start mock recording")
        }
        
        // 3. Simulate User Releasing the pad
        let result = await mockAudioService.stopRecording()
        if let recording = result {
            // Orchestrator takes the recording, adds to REAL repo, and assigns to Pad 0
            let newSampleID = realRepository.addSample(url: recording.url)
            orchestrator.assignSample(newSampleID, toPad: 0)
            orchestrator.isRecordingPadIndex = nil
        }
        
        // 4. Assert Integration Success
        XCTAssertEqual(realRepository.allSamples.count, 1, "Real repository must successfully ingest the new recording")
        XCTAssertNotNil(orchestrator.padAssignments[0], "Orchestrator must successfully map the new repository ID to Pad 0")
        XCTAssertFalse(mockAudioService.isRecording, "Audio service must be shut off")
    }
    
    @MainActor
        func testEditorToPadThumbnailIntegration() throws {
            // 1. Setup: Create a sample, assign it, and generate the pad's UI state
            let sampleID = realRepository.addSample(url: URL(fileURLWithPath: "/test.m4a"))
            orchestrator.assignSample(sampleID, toPad: 1)
            
            // 2. Fetch the Pad ViewModel
            // We can also use XCTUnwrap here for safety!
            let padVM = try XCTUnwrap(orchestrator.getViewModel(for: 1))
            
            // Verify initial domain state
            let initialDomainSample = try XCTUnwrap(realRepository.getWaveformSource(for: sampleID))
            XCTAssertEqual(initialDomainSample.startTimeRatio, 0.0)
            
            // 3. Simulate Opening Editor and Making Edits
            let editorVM = try XCTUnwrap(WaveformEditorViewModel(
                sampleID: sampleID,
                repository: realRepository,
                audioService: mockAudioService,
                generator: mockGenerator
            ))
            
            // User drags slider to 0.4 and saves
            editorVM.tempStartRatio = 0.4
            editorVM.saveEdits()
            
            // 4. Assert Integration Success
            let updatedDomainSample = try XCTUnwrap(realRepository.getWaveformSource(for: padVM.sampleID))
            XCTAssertEqual(updatedDomainSample.startTimeRatio, 0.4, "The Pad must instantly reflect the trim changes saved by the Editor via the shared Repository")
        }
}
