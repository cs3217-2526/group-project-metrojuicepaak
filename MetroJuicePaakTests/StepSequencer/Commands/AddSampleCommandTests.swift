//
//  AddSampleCommandTests.swift
//  MetroJuicePaak
//
//  Created by Edwin Wong on 18/04/2026.
//


import XCTest
@testable import MetroJuicePaak

final class AddSampleCommandTests: XCTestCase {
    
    var viewModel: StepSequencerViewModel!
    private var testTrackId: UUID!
    private let sampleID_A = ObjectIdentifier(DummySample())
    private let sampleID_B = ObjectIdentifier(DummySample())
    
    override func setUp() {
        super.setUp()
        let mockEngine = MockMusicEngine()
        let mockRepo = MockAudioSampleRepository()
        viewModel = StepSequencerViewModel(repository: mockRepo, musicEngine: mockEngine)
        
        viewModel.executeAddTrack()
        testTrackId = viewModel.sequencerModel.tracks[0].id
    }
    
    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }
    
    func testInitialAssignment_Lifecycle() {
        viewModel.executeAssignSample(trackId: testTrackId, sampleID: sampleID_A)
        XCTAssertEqual(viewModel.sequencerModel.tracks[0].sampleID, sampleID_A)
        
        viewModel.undo()
        XCTAssertNil(viewModel.sequencerModel.tracks[0].sampleID)
        
        viewModel.redo()
        XCTAssertEqual(viewModel.sequencerModel.tracks[0].sampleID, sampleID_A)
    }
    
    func testSwapSample_Lifecycle() {
        viewModel.executeAssignSample(trackId: testTrackId, sampleID: sampleID_A)
        
        viewModel.executeAssignSample(trackId: testTrackId, sampleID: sampleID_B)
        XCTAssertEqual(viewModel.sequencerModel.tracks[0].sampleID, sampleID_B)
        
        viewModel.undo()
        XCTAssertEqual(viewModel.sequencerModel.tracks[0].sampleID, sampleID_A, "Must restore previous sample, not just set to nil")
        
        viewModel.redo()
        XCTAssertEqual(viewModel.sequencerModel.tracks[0].sampleID, sampleID_B)
    }
}
