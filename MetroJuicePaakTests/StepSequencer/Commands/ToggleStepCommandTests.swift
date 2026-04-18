//
//  ToggleStepCommandTests.swift
//  MetroJuicePaak
//
//  Created by Edwin Wong on 18/04/2026.
//


import XCTest
@testable import MetroJuicePaak

final class ToggleStepCommandTests: XCTestCase {
    
    var viewModel: StepSequencerViewModel!
    var mockEngine: MockMusicEngine!
    private var testTrackId: UUID!
    private let targetStep = 5
    
    override func setUp() {
        super.setUp()
        mockEngine = MockMusicEngine()
        let mockRepo = MockAudioSampleRepository()
        viewModel = StepSequencerViewModel(repository: mockRepo, musicEngine: mockEngine)
        
        viewModel.executeAddTrack()
        testTrackId = viewModel.sequencerModel.tracks[0].id
    }
    
    override func tearDown() {
        viewModel = nil
        mockEngine = nil
        super.tearDown()
    }
    
    func testLifecycle() {
        XCTAssertFalse(viewModel.sequencerModel.tracks[0].steps[targetStep])
        
        viewModel.executeToggleStep(trackId: testTrackId, stepIndex: targetStep)
        
        XCTAssertTrue(viewModel.sequencerModel.tracks[0].steps[targetStep])
        XCTAssertTrue(mockEngine.latestSnapshot!.tracks[testTrackId]!.steps[targetStep])
        
        viewModel.undo()
        XCTAssertFalse(viewModel.sequencerModel.tracks[0].steps[targetStep])
        
        viewModel.redo()
        XCTAssertTrue(viewModel.sequencerModel.tracks[0].steps[targetStep])
    }
}
