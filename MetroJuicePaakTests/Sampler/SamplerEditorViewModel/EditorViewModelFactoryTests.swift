import XCTest
import AVFoundation
@testable import MetroJuicePaak

final class EditorViewModelFactoryTests: XCTestCase {
    
    var factory: EditorViewModelFactory!
    var mockRepository: AudioSampleRepository!
    var mockAudioService: MockAudioService!
    var mockGenerator: MockWaveformGenerator!
    var realRegistry: EffectRegistry!
    
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
        mockGenerator = MockWaveformGenerator()
        realRegistry = EffectRegistry()
        
        factory = EditorViewModelFactory(
            repository: mockRepository,
            audioService: mockAudioService,
            waveformGenerator: mockGenerator,
            effectRegistry: realRegistry
        )
    }
    
    @MainActor
    func testMakeSamplerEditor_WithValidSample() async throws {
        let sampleID = mockRepository.addSample(url: createDummyAudioFile())
        
        let editorVM = factory.makeSamplerEditor(for: sampleID)
        
        XCTAssertNotNil(editorVM, "Factory must return a valid SamplerEditorViewModel for an existing sample")
        XCTAssertEqual(editorVM?.sampleID, sampleID, "Factory must pass the correct sampleID into the created ViewModel")
    }
    
    @MainActor
    func testMakeSamplerEditor_WithInvalidSample() async {
        let fakeObject = NSObject()
        let fakeID = ObjectIdentifier(fakeObject)
        
        let editorVM = factory.makeSamplerEditor(for: fakeID)
        
        XCTAssertNil(editorVM, "Factory must return nil if the requested sample ID does not exist in the repository")
    }
    
    @MainActor
    func testMakeEffectsEditor_WithValidSample() async throws {
        let sampleID = mockRepository.addSample(url: createDummyAudioFile())
        
        let effectsVM = factory.makeEffectsEditor(for: sampleID)
        
        XCTAssertNotNil(effectsVM, "Factory must return a valid EffectChainEditorViewModel for an existing sample")
    }
    
    @MainActor
    func testMakeEffectsEditor_WithInvalidSample() async {
        let fakeObject = NSObject()
        let fakeID = ObjectIdentifier(fakeObject)
        
        let effectsVM = factory.makeEffectsEditor(for: fakeID)
        
        XCTAssertNil(effectsVM, "Factory must return nil if the requested sample ID does not exist in the repository")
    }

}
