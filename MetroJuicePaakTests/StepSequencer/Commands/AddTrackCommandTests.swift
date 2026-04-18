//
//  AddTrackCommandTests.swift
//  MetroJuicePaak
//
//  Created by Edwin Wong on 18/04/2026.
//


import XCTest
@testable import MetroJuicePaak

final class AddTrackCommandTests: XCTestCase {
    
    var viewModel: StepSequencerViewModel!
    var mockEngine: MockMusicEngine!
    
    override func setUp() {
        super.setUp()
        mockEngine = MockMusicEngine()
        let mockRepo = MockAudioSampleRepository()
        viewModel = StepSequencerViewModel(repository: mockRepo, musicEngine: mockEngine)
    }
    
    override func tearDown() {
        viewModel = nil
        mockEngine = nil
        super.tearDown()
    }
    
    func testLifecycle() {
        XCTAssertTrue(viewModel.sequencerModel.tracks.isEmpty)
        
        viewModel.executeAddTrack()
        
        XCTAssertEqual(viewModel.sequencerModel.tracks.count, 1)
        let trackId = viewModel.sequencerModel.tracks[0].id
        XCTAssertNotNil(mockEngine.latestSnapshot?.tracks[trackId])
        
        viewModel.undo()
        
        XCTAssertTrue(viewModel.sequencerModel.tracks.isEmpty)
        XCTAssertTrue(mockEngine.latestSnapshot!.tracks.isEmpty)
        
        viewModel.redo()
        
        XCTAssertEqual(viewModel.sequencerModel.tracks.count, 1)
        XCTAssertEqual(viewModel.sequencerModel.tracks[0].id, trackId, "UUID must be perfectly restored")
    }
}
