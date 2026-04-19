//
//  SamplerViewModelTests.swift
//  MetroJuicePaakTests
//
//  Created by proglab on 19/4/26.
//

import XCTest
@testable import MetroJuicePaak

final class SamplerViewModelTests: XCTestCase {
    
    var orchestrator: SamplerViewModel!
    var mockRepository: AudioSampleRepository!
    var mockAudioService: MockAudioService!
    var mockGenerator: MockWaveformGenerator!
    
    @MainActor
    override func setUp() {
        super.setUp()
        mockRepository = AudioSampleRepository()
        mockAudioService = MockAudioService()
        mockGenerator = MockWaveformGenerator()
        
        orchestrator = SamplerViewModel(
            repository: mockRepository,
            audioService: mockAudioService,
            waveformGenerator: mockGenerator
        )
    }
    
    @MainActor
    func testPadAssignmentAndCaching() {
        // 1. Assign a sample to pad 0
        let sampleID = mockRepository.addSample(url: URL(fileURLWithPath: "/dummy.m4a"))
        orchestrator.assignSample(sampleID, toPad: 0)
        
        // Assert assignment
        XCTAssertEqual(orchestrator.padAssignments[0], sampleID, "Sample ID should be explicitly assigned to Pad 0")
        
        // 2. Test Caching
        let vm1 = orchestrator.getViewModel(for: 0)
        let vm2 = orchestrator.getViewModel(for: 0)
        
        // Assert exact identical instance is returned (pointer equality)
        XCTAssertTrue(vm1 === vm2, "Orchestrator must cache the SamplerPadViewModel to prevent UI memory leaks")
    }
    
    @MainActor
    func testEditModeRouting_ToEditor() {
        // Setup: Assigned pad in Edit Mode
        orchestrator.isEditMode = true
        let sampleID = mockRepository.addSample(url: URL(fileURLWithPath: "/dummy.m4a"))
        orchestrator.assignSample(sampleID, toPad: 1)
        
        // Action
        orchestrator.handlePadTap(padIndex: 1)
        
        // Assert
        XCTAssertEqual(orchestrator.sampleIDToEdit?.id, sampleID, "Tapping an assigned pad in Edit Mode must route to the Waveform Editor")
        XCTAssertNil(mockAudioService.lastPlayedSample, "Audio must NOT play when in Edit Mode")
    }
    
    @MainActor
    func testEditModeRouting_ToPicker() {
        // Setup: Empty pad in Edit Mode
        orchestrator.isEditMode = true
        // Pad 2 is completely empty
        
        // Action
        orchestrator.handlePadTap(padIndex: 2)
        
        // Assert
        XCTAssertEqual(orchestrator.padIndexAwaitingAssignment?.id, 2, "Tapping an empty pad in Edit Mode must route to the Sample Picker")
    }
    
    @MainActor
    func testPlaybackRouting_NormalMode() async {
        // Setup: Assigned pad in Normal Mode
        orchestrator.isEditMode = false
        let sampleID = mockRepository.addSample(url: URL(fileURLWithPath: "/dummy.m4a"))
        orchestrator.assignSample(sampleID, toPad: 1)
        
        // Action: We directly await playPad to avoid testing Task timing
        await orchestrator.playPad(padIndex: 1)
        
        // Assert
        XCTAssertNotNil(mockAudioService.lastPlayedSample, "Audio service must receive the playback command")
    }
}
