//
//  ChangeStepCountCommandTests.swift
//  MetroJuicePaak
//
//  Created by Edwin Wong on 18/04/2026.
//


import XCTest
@testable import MetroJuicePaak

final class ChangeStepCountCommandTests: XCTestCase {
    
    var viewModel: StepSequencerViewModel!
    private var testTrackId: UUID!
    
    override func setUp() {
        super.setUp()
        let mockEngine = MockMusicEngine()
        let mockRepo = MockAudioSampleRepository()
        viewModel = StepSequencerViewModel(repository: mockRepo, musicEngine: mockEngine)
        
        viewModel.executeAddTrack()
        testTrackId = viewModel.sequencerModel.tracks[0].id
        viewModel.executeToggleStep(trackId: testTrackId, stepIndex: 15)
    }
    
    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }
    
    func testLifecycle_BypassesAlgorithmOnUndo() {
        viewModel.executeChangeStepCount(to: 8)
        
        XCTAssertEqual(viewModel.sequencerModel.stepCount, 8)
        XCTAssertEqual(viewModel.sequencerModel.tracks[0].steps.count, 8)
        
        viewModel.undo()
        
        XCTAssertEqual(viewModel.sequencerModel.stepCount, 16)
        XCTAssertEqual(viewModel.sequencerModel.tracks[0].steps.count, 16)
        XCTAssertTrue(viewModel.sequencerModel.tracks[0].steps[15], "Deleted step off the end of the 8-count grid must be perfectly restored via dictionary backup")
        
        viewModel.redo()
        
        XCTAssertEqual(viewModel.sequencerModel.stepCount, 8)
        XCTAssertEqual(viewModel.sequencerModel.tracks[0].steps.count, 8)
    }
    
    // MARK: - Step Count Algorithm Tests
        
    func testSetStepCount_Expanding_SpreadsStepsProportionally() {
        viewModel.executeAddTrack()
        let trackId = viewModel.sequencerModel.tracks[0].id
        
        // Create a basic 4-on-the-floor beat: [True, False, False, False, True, False, False, False]
        viewModel.setStepCount(8)
        viewModel.executeToggleStep(trackId: trackId, stepIndex: 0)
        viewModel.executeToggleStep(trackId: trackId, stepIndex: 4)
        
        viewModel.setStepCount(16)
        
        let steps = viewModel.sequencerModel.tracks[0].steps
        XCTAssertEqual(steps.count, 16)
        
        // Check the math:
        // Old index 0 -> New index 0
        // Old index 4 -> New index 8 (4 * 16 / 8)
        XCTAssertTrue(steps[0], "First step should remain at index 0")
        XCTAssertTrue(steps[8], "Step at index 4 should stretch to index 8")
        
        // Ensure no phantom steps were created
        let activeSteps = steps.filter { $0 }.count
        XCTAssertEqual(activeSteps, 2, "Only the 2 original active steps should exist after expansion")
    }
    
    func testSetStepCount_Shrinking_CompressesStepsCorrectly() {
        viewModel.executeAddTrack()
        let trackId = viewModel.sequencerModel.tracks[0].id
        viewModel.setStepCount(16)
        
        // Toggle every EVEN step: [T, F, T, F, T, F, T, F, T, F, T, F, T, F, T, F]
        for i in 0..<16 where i % 2 == 0 {
            viewModel.executeToggleStep(trackId: trackId, stepIndex: i)
        }
        
        viewModel.setStepCount(8)
        
        let steps = viewModel.sequencerModel.tracks[0].steps
        XCTAssertEqual(steps.count, 8)
        
        // Check the math:
        // New index 0 -> Old index 0 (True)
        // New index 1 -> Old index 2 (True)
        // All 8 steps should now be True!
        let activeSteps = steps.filter { $0 }.count
        XCTAssertEqual(activeSteps, 8, "The down-sampling math should compress all even steps into a solid block of 8")
        XCTAssertTrue(steps.allSatisfy { $0 }, "Every step in the new 8-step array should be True")
    }
    
    func testSetStepCount_PlayheadBounds_ResetsIfGridShrinksTooSmall() {
        viewModel.executeAddTrack()
        viewModel.setStepCount(32)
        
        viewModel.currentStep = 30
        
        viewModel.setStepCount(16)
        
        XCTAssertEqual(viewModel.currentStep, 0, "The playhead must reset to 0 to prevent an out-of-bounds crash on the UI thread")
    }
    
    func testSetStepCount_PlayheadBounds_RemainsIfGridIsLargeEnough() {
        viewModel.executeAddTrack()
        viewModel.setStepCount(16)
        
        viewModel.currentStep = 10
        
        viewModel.setStepCount(32)
        
        XCTAssertEqual(viewModel.currentStep, 10, "The playhead should not reset if its current position is still valid within the new step count")
    }
}
