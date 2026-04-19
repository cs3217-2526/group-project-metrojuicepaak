//
//  StepSequencerIntegrationTests.swift
//  MetroJuicePaak
//
//  Created by Edwin Wong on 19/04/2026.
//


import XCTest
@testable import MetroJuicePaak

final class StepSequencerIntegrationTests: XCTestCase {
    
    var viewModel: StepSequencerViewModel!
    var mockEngine: MockMusicEngine!
    var mockRepo: MockAudioSampleRepository!
    
    private let kickSampleID = ObjectIdentifier(DummySample())
    private let snareSampleID = ObjectIdentifier(DummySample())
    
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
    
    // MARK: - The Full User Journey Integration Test
    
    func testFullUserCompositionWorkflow() {
        // ---------------------------------------------------------
        // PHASE 1: The Setup (User creates a 2-track sequence)
        // ---------------------------------------------------------
        
        // 1. Add Kick Track
        viewModel.executeAddTrack()
        let kickTrackId = viewModel.sequencerModel.tracks[0].id
        viewModel.executeAssignSample(trackId: kickTrackId, sampleID: kickSampleID)
        
        // 2. Add Snare Track
        viewModel.executeAddTrack()
        let snareTrackId = viewModel.sequencerModel.tracks[1].id
        viewModel.executeAssignSample(trackId: snareTrackId, sampleID: snareSampleID)
        
        XCTAssertEqual(viewModel.sequencerModel.tracks.count, 2)
        XCTAssertEqual(mockEngine.latestSnapshot?.tracks.count, 2, "Engine must be perfectly synced with the model via snapshots")
        XCTAssertTrue(viewModel.undoRedoManager.canUndo, "Undo stack should be tracking these setup commands")
        
        // ---------------------------------------------------------
        // PHASE 2: The Composition (Plotting a beat)
        // ---------------------------------------------------------
        
        // 3. User programs a simple 4-on-the-floor kick (Steps 0, 4, 8, 12)
        for i in stride(from: 0, to: 16, by: 4) {
            viewModel.executeToggleStep(trackId: kickTrackId, stepIndex: i)
        }
        
        // 4. User programs a snare on the 2 and 4 (Steps 4, 12)
        viewModel.executeToggleStep(trackId: snareTrackId, stepIndex: 4)
        viewModel.executeToggleStep(trackId: snareTrackId, stepIndex: 12)
        
        let activeKicks = viewModel.sequencerModel.tracks[0].steps.filter { $0 }.count
        let activeSnares = viewModel.sequencerModel.tracks[1].steps.filter { $0 }.count
        XCTAssertEqual(activeKicks, 4)
        XCTAssertEqual(activeSnares, 2)
        
        // ---------------------------------------------------------
        // PHASE 3: Global Transport Changes
        // ---------------------------------------------------------
        
        // 5. User starts playback and hypes up the tempo
        viewModel.togglePlayback()
        viewModel.sequencerModel.bpm = 120
        viewModel.increaseBPM() // 121
        viewModel.increaseBPM() // 122
        
        XCTAssertTrue(mockEngine.isRunning)
        XCTAssertEqual(mockEngine.latestSnapshot?.bpm, 122, "Engine snapshot must instantly reflect direct BPM mutations")
        
        // ---------------------------------------------------------
        // PHASE 4: The Grid Shift (Stretching the sequence)
        // ---------------------------------------------------------
        
        // 6. User expands the 16-step beat into a 32-step grid
        viewModel.executeChangeStepCount(to: 32)
        
        XCTAssertEqual(viewModel.sequencerModel.stepCount, 32)
        XCTAssertEqual(viewModel.sequencerModel.tracks[0].steps.count, 32)
        
        // ---------------------------------------------------------
        // PHASE 5: The "Nevermind" Reversal (Testing deep integration)
        // ---------------------------------------------------------
        
        // The user decides they hate the 32-step expansion, the snare, and the entire second track.
        // They hit Undo exactly 4 times:
        // 1. Undoes the step count expansion (32 -> 16)
        // 2. Undoes the Snare step 12
        // 3. Undoes the Snare step 4
        // (Remember: We added 4 kick steps and assigned samples, so those are further down the stack)
        
        viewModel.undo() // Reverts Step Count
        viewModel.undo() // Reverts Snare Step 12
        viewModel.undo() // Reverts Snare Step 4
        
        XCTAssertEqual(viewModel.sequencerModel.stepCount, 16, "Grid should be perfectly restored to 16 steps")
        XCTAssertEqual(viewModel.sequencerModel.tracks[1].steps.filter { $0 }.count, 0, "Snare track should be completely wiped of active steps after undoing")
        
        XCTAssertTrue(mockEngine.isRunning, "Undo operations must not interrupt active playback transport")
        XCTAssertEqual(viewModel.sequencerModel.bpm, 122, "Undo operations must not overwrite the live BPM")
    }
}
