//
//  DeleteSampleCommandTests.swift
//  MetroJuicePaak
//
//  Created by Edwin Wong on 18/04/2026.
//


import XCTest
@testable import MetroJuicePaak

final class DeleteSampleCommandTests: XCTestCase {
    
    var viewModel: StepSequencerViewModel!
    private var testTrackId: UUID!
    private let sampleID = ObjectIdentifier(DummySample())
    
    override func setUp() {
        super.setUp()
        let mockEngine = MockMusicEngine()
        let mockRepo = MockAudioSampleRepository()
        viewModel = StepSequencerViewModel(repository: mockRepo, musicEngine: mockEngine)
        
        viewModel.executeAddTrack()
        testTrackId = viewModel.sequencerModel.tracks[0].id
        viewModel.executeAssignSample(trackId: testTrackId, sampleID: sampleID)
    }
    
    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }
    
    func testLifecycle() {
        viewModel.executeRemoveSample(trackId: testTrackId)
        XCTAssertNil(viewModel.sequencerModel.tracks[0].sampleID)
        
        viewModel.undo()
        XCTAssertEqual(viewModel.sequencerModel.tracks[0].sampleID, sampleID)
        
        viewModel.redo()
        XCTAssertNil(viewModel.sequencerModel.tracks[0].sampleID)
    }
}
