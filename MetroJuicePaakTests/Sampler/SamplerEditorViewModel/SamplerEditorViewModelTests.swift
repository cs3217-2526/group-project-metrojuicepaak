import XCTest
import AVFoundation
@testable import MetroJuicePaak

final class SamplerEditorViewModelTests: XCTestCase {
    
    var editorVM: SamplerEditorViewModel!
    var mockRepository: AudioSampleRepository!
    var mockAudioService: MockAudioService!
    var sampleID: ObjectIdentifier!
    
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
        
        mockRepository = AudioSampleRepository()
        mockAudioService = try await MockAudioService()
        let mockGenerator = MockWaveformGenerator()
        
        // Add sample and manually alter its starting domain state to 0.2 and 0.8
        sampleID = mockRepository.addSample(url: createDummyAudioFile())
        let editable = mockRepository.getEditableSample(for: sampleID)!
        try? editable.setStartTimeRatio(0.2)
        try? editable.setEndTimeRatio(0.8)
        
        // Initialize the Editor sandbox
        editorVM = SamplerEditorViewModel(
            sampleID: sampleID,
            repository: mockRepository,
            audioService: mockAudioService,
            generator: mockGenerator
        )
    }
    
    @MainActor
    func testInitializationBackups() async {
        XCTAssertEqual(editorVM.tempStartRatio, 0.2, "Editor must initialize temp sliders to the exact domain ratios")
        XCTAssertEqual(editorVM.tempEndRatio, 0.8, "Editor must initialize temp sliders to the exact domain ratios")
    }
    
    @MainActor
    func testCancelDiscardingEdits() async {
        // Action: User aggressively drags the slider to 0.5, but hits Cancel
        editorVM.tempStartRatio = 0.5
        editorVM.cancelEdits()
        
        // Assert: Domain model remains completely untouched
        let domainModel = mockRepository.getWaveformSource(for: sampleID)!
        XCTAssertEqual(domainModel.startTimeRatio, 0.2, "Cancel must revert changes and protect the underlying domain model")
    }
    
    @MainActor
    func testSaveCommittingEdits() async {
        // Action: User drags the slider to 0.5 and hits Save
        editorVM.tempStartRatio = 0.5
        editorVM.saveEdits()
        
        // Assert: Domain model is explicitly mutated
        let domainModel = mockRepository.getWaveformSource(for: sampleID)!
        XCTAssertEqual(domainModel.startTimeRatio, 0.5, "Save must commit the transient UI state to the domain model")
    }
}
