import XCTest
@testable import MetroJuicePaak
final class WaveformEditorViewModelTests: XCTestCase {
    
    var editorVM: WaveformEditorViewModel!
    var mockRepository: AudioSampleRepository!
    var mockAudioService: MockAudioService!
    var sampleID: ObjectIdentifier!
    
    @MainActor
    override func setUp() {
        super.setUp()
        mockRepository = AudioSampleRepository()
        mockAudioService = MockAudioService()
        let mockGenerator = MockWaveformGenerator()
        
        // Add sample and manually alter its starting domain state to 0.2 and 0.8
        sampleID = mockRepository.addSample(url: URL(fileURLWithPath: "/dummy.m4a"))
        let editable = mockRepository.getEditableSample(for: sampleID)!
        try? editable.setStartTimeRatio(0.2)
        try? editable.setEndTimeRatio(0.8)
        
        // Initialize the Editor sandbox
        editorVM = WaveformEditorViewModel(
            sampleID: sampleID,
            repository: mockRepository,
            audioService: mockAudioService,
            generator: mockGenerator
        )
    }
    
    @MainActor
    func testInitializationBackups() {
        XCTAssertEqual(editorVM.tempStartRatio, 0.2, "Editor must initialize temp sliders to the exact domain ratios")
        XCTAssertEqual(editorVM.tempEndRatio, 0.8)
    }
    
    @MainActor
    func testCancelDiscardingEdits() {
        // Action: User aggressively drags the slider to 0.5, but hits Cancel
        editorVM.tempStartRatio = 0.5
        editorVM.cancelEdits()
        
        // Assert: Domain model remains completely untouched
        let domainModel = mockRepository.getWaveformSource(for: sampleID)!
        XCTAssertEqual(domainModel.startTimeRatio, 0.2, "Cancel must revert changes and protect the underlying domain model")
    }
    
    @MainActor
    func testSaveCommittingEdits() {
        // Action: User drags the slider to 0.5 and hits Save
        editorVM.tempStartRatio = 0.5
        editorVM.saveEdits()
        
        // Assert: Domain model is explicitly mutated
        let domainModel = mockRepository.getWaveformSource(for: sampleID)!
        XCTAssertEqual(domainModel.startTimeRatio, 0.5, "Save must commit the transient UI state to the domain model")
    }
}
