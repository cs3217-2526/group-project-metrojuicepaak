//
//  DeleteTrackCommandTests.swift
//  MetroJuicePaak
//
//  Created by Edwin Wong on 18/04/2026.
//


import XCTest
@testable import MetroJuicePaak

final class DeleteTrackCommandTests: XCTestCase {
    
    var viewModel: StepSequencerViewModel!
    private let sampleID = ObjectIdentifier(DummySample())
    
    override func setUp() {
        super.setUp()
        let mockEngine = MockMusicEngine()
        let mockRepo = MockAudioSampleRepository()
        viewModel = StepSequencerViewModel(repository: mockRepo, musicEngine: mockEngine)
        
        viewModel.executeAddTrack()
        let trackId = viewModel.sequencerModel.tracks[0].id
        viewModel.executeAssignSample(trackId: trackId, sampleID: sampleID)
        viewModel.executeToggleStep(trackId: trackId, stepIndex: 3)
    }
    
    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }
    
    func testLifecycle_DeepRestoration() {
        let trackId = viewModel.sequencerModel.tracks[0].id
        
        viewModel.executeRemoveTrack(trackId: trackId)
        XCTAssertTrue(viewModel.sequencerModel.tracks.isEmpty)
        
        viewModel.undo()
        
        XCTAssertEqual(viewModel.sequencerModel.tracks.count, 1)
        XCTAssertEqual(viewModel.sequencerModel.tracks[0].id, trackId, "UUID must be retained")
        XCTAssertEqual(viewModel.sequencerModel.tracks[0].sampleID, sampleID, "Sample assignment must be restored")
        XCTAssertTrue(viewModel.sequencerModel.tracks[0].steps[3], "Pattern edits must be restored")
        
        viewModel.redo()
        XCTAssertTrue(viewModel.sequencerModel.tracks.isEmpty)
    }
}
