import XCTest
import AVFoundation
@testable import MetroJuicePaak

final class SamplerViewModelTests: XCTestCase {
    
    var orchestrator: SamplerViewModel!
    var mockRepository: AudioSampleRepository!
    var mockAudioService: MockAudioService!
    var mockGenerator: MockWaveformGenerator!
    var editorFactory: EditorViewModelFactory!

    private func createDummyAudioFile() -> URL {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 44100.0, channels: 1) else { return tempURL }
        let _ = try? AVAudioFile(forWriting: tempURL, settings: format.settings)
        return tempURL
    }
    
    @MainActor
    override func setUp() async throws {
        try await super.setUp()
        
        mockRepository = AudioSampleRepository()
        mockGenerator = MockWaveformGenerator()
        mockAudioService = try await MockAudioService()
        
        let realRegistry = EffectRegistry()
        
        editorFactory = EditorViewModelFactory(
            repository: mockRepository,
            audioService: mockAudioService,
            waveformGenerator: mockGenerator,
            effectRegistry: realRegistry
        )
        
        orchestrator = SamplerViewModel(
            repository: mockRepository,
            audioService: mockAudioService,
            editorFactory: editorFactory,
            padViewModelGenerator: mockGenerator
        )
    }
    
    @MainActor
    func testPadAssignmentAndCaching() async {
        let sampleID = mockRepository.addSample(url: createDummyAudioFile())
        orchestrator.assignSample(sampleID, toPad: 0)
        
        XCTAssertEqual(orchestrator.padAssignments[0], sampleID, "Sample ID should be explicitly assigned to Pad 0")
        
        let vm1 = orchestrator.getViewModel(for: 0)
        let vm2 = orchestrator.getViewModel(for: 0)
        
        XCTAssertTrue(vm1 === vm2, "Orchestrator must cache the SamplerPadViewModel to prevent UI memory leaks")
    }
    
    @MainActor
    func testEditModeRouting_ToEditor() async {
        orchestrator.isEditMode = true
        let sampleID = mockRepository.addSample(url: createDummyAudioFile())
        orchestrator.assignSample(sampleID, toPad: 1)
        
        orchestrator.handlePadTap(padIndex: 1)
        
        XCTAssertEqual(orchestrator.sampleIDToEdit?.id, sampleID, "Tapping an assigned pad in Edit Mode must route to the Sampler Editor")
        XCTAssertNil(mockAudioService.lastPlayedSample, "Audio must NOT play when in Edit Mode")
    }
    
    @MainActor
    func testEditModeRouting_ToPicker() async {
        orchestrator.isEditMode = true
        orchestrator.handlePadTap(padIndex: 2)
        XCTAssertEqual(orchestrator.padIndexAwaitingAssignment?.id, 2, "Tapping an empty pad in Edit Mode must route to the Sample Picker")
    }
    
    @MainActor
    func testPlaybackRouting_NormalMode() async {
        orchestrator.isEditMode = false
        let sampleID = mockRepository.addSample(url: createDummyAudioFile())
        orchestrator.assignSample(sampleID, toPad: 1)
        
        await orchestrator.playPad(padIndex: 1)
        XCTAssertNotNil(mockAudioService.lastPlayedSample, "Audio service must receive the playback command")
    }
    
    @MainActor
    func testEditorViewModelFactories() async {
        let sampleID = mockRepository.addSample(url: createDummyAudioFile())
        
        let editorVM = orchestrator.getEditorViewModel(for: sampleID)
        let effectsVM = orchestrator.getEffectsEditorViewModel(for: sampleID)
        
        XCTAssertNotNil(editorVM, "Orchestrator should delegate SamplerEditorViewModel creation to the factory")
        XCTAssertNotNil(effectsVM, "Orchestrator should delegate EffectChainEditorViewModel creation to the factory")
        
        try? await Task.sleep(nanoseconds: 100_000_000)
    }

}
