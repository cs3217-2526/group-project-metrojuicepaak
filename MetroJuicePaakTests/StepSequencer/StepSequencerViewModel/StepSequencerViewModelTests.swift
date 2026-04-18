//
//  StepSequencerViewModelTests.swift
//  MetroJuicePaak
//
//  Created by Edwin Wong on 18/04/2026.
//


import XCTest
@testable import MetroJuicePaak

final class StepSequencerViewModelTests: XCTestCase {
    
    var viewModel: StepSequencerViewModel!
    var mockEngine: MockMusicEngine!
    var mockRepo: MockAudioSampleRepository!
    
    override func setUp() {
        super.setUp()
        mockEngine = MockMusicEngine()
        mockRepo = MockAudioSampleRepository()
        viewModel = StepSequencerViewModel(repository: mockRepo, musicEngine: mockEngine)
    }
    
    override func tearDown() {
        viewModel = nil
        mockEngine = nil
        mockRepo = nil
        super.tearDown()
    }
    
    // MARK: - Transport & State Tests
    
    func testTogglePlayback_StartsAndStopsEngine() {
        XCTAssertFalse(viewModel.isPlaying)
        XCTAssertFalse(mockEngine.isRunning)
        
        viewModel.togglePlayback()
        
        XCTAssertTrue(viewModel.isPlaying)
        XCTAssertTrue(mockEngine.isRunning)
        
        viewModel.togglePlayback()
        
        XCTAssertFalse(viewModel.isPlaying)
        XCTAssertFalse(mockEngine.isRunning)
    }
    
    // MARK: - Direct Mutation Tests (No Undo/Redo)
    
    func testBPM_DirectMutationAndClamping() {
        viewModel.sequencerModel.bpm = 120
        
        viewModel.increaseBPM()
        XCTAssertEqual(viewModel.sequencerModel.bpm, 121)
        XCTAssertEqual(mockEngine.latestSnapshot?.bpm, 121, "Snapshot must push instantly on BPM change")
        
        viewModel.sequencerModel.bpm = 300
        viewModel.increaseBPM()
        XCTAssertEqual(viewModel.sequencerModel.bpm, 300, "BPM should clamp at maximum 300")
        
        viewModel.sequencerModel.bpm = 40
        viewModel.decreaseBPM()
        XCTAssertEqual(viewModel.sequencerModel.bpm, 40, "BPM should clamp at minimum 40")
    }
}