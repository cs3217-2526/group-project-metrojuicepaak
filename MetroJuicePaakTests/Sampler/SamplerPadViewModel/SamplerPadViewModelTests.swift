import XCTest
@testable import MetroJuicePaak

final class SamplerPadViewModelTests: XCTestCase {
    
    @MainActor
    func testNameResolution() async { 
        let repository = AudioSampleRepository()
        
        let sampleID = repository.addSample(url: URL(fileURLWithPath: "/dummy.m4a"))
        try? repository.renameSample(id: sampleID, to: "Kick Drum")
        
        let padVM = SamplerPadViewModel(
            sampleID: sampleID,
            repository: repository,
            generator: MockWaveformGenerator()
        )
        
        XCTAssertEqual(padVM.displayName, "Kick Drum", "ViewModel must map the correct name")
        
        try? await Task.sleep(nanoseconds: 10_000_000)
    }
}
