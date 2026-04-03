//
//  StepSequencerViewModel.swift
//  MetroJuicePaak
//
//  Created by Edwin Wong on 23/03/2026.
//

import Foundation
import Observation

@Observable
class StepSequencerViewModel {
    private(set) var sequencerModel: StepSequencerModel
    
    private let sessionManager: AudioSampleRepositoryViewModel // Provided via init
    private let musicEngine: MusicEngine // Provided via init
    private let undoRedoManager = UndoRedoManager()
    
    var isPlaying: Bool = false
    var currentStep: Int = 0 // Updated by a callback from MusicEngine in real implementation
    
    // The gatekeeper computed property
    var bpm: Double {
        get { sequencerModel.bpm }
        set {
            sequencerModel.bpm = newValue
            publishSnapshot()
        }
    }
    
    let availableLengths: [Int] = [6, 8, 12, 16, 24, 32]
    
    var canUndo: Bool { undoRedoManager.canUndo }
    var canRedo: Bool { undoRedoManager.canRedo }
    
    init(sessionManager: AudioSampleRepositoryViewModel, musicEngine: MusicEngine) {
        self.sessionManager = sessionManager
        self.musicEngine = musicEngine
        self.sequencerModel = StepSequencerModel()
    }
    
    // MARK: - The Bridge
    
    private func publishSnapshot() {
        let snapshot = SequencerSnapshot(
            tracks: sequencerModel.tracks,
            bpm: sequencerModel.bpm
        )
        musicEngine.apply(snapshot: snapshot)
    }
    
    // MARK: - Playback
    
    func togglePlayback() {
        if isPlaying {
            stop() //
        } else {
            play() //
        }
    }
    
    private func play() {
        isPlaying = true //
        currentStep = 0 //
        publishSnapshot() // Push latest state before igniting
        musicEngine.startSequencer() //
    }
    
    private func stop() {
        isPlaying = false //
        musicEngine.stopSequencer() //
        currentStep = 0 //
    }
    
    // MARK: - Target Mutations (Called by Commands)
    
    internal func mutateStep(trackId: UUID, stepIndex: Int) {
        guard sequencerModel.tracks[trackId] != nil,
              stepIndex < sequencerModel.sequenceLength else { return } //
        
        sequencerModel.tracks[trackId]?.steps[stepIndex].toggle() //
        publishSnapshot() //
    }
    
    internal func addTrack(track: SequencerTrack) {
        sequencerModel.tracks[track.trackId] = track //
        if !sequencerModel.trackOrder.contains(track.trackId) { //
            sequencerModel.trackOrder.append(track.trackId) //
        }
        publishSnapshot() //
    }
    
    internal func removeTrack(at trackId: UUID) {
        sequencerModel.tracks.removeValue(forKey: trackId) //
        sequencerModel.trackOrder.removeAll { $0 == trackId } //
        publishSnapshot() //
    }
    
    internal func restoreTrack(_ track: SequencerTrack, at index: Int) {
        // 1. Put the data back in the dictionary
        sequencerModel.tracks[track.trackId] = track
        
        // 2. Put the UUID back in the exact UI order index to preserve visual consistency
        if !sequencerModel.trackOrder.contains(track.trackId) {
            let safeIndex = min(max(0, index), sequencerModel.trackOrder.count)
            sequencerModel.trackOrder.insert(track.trackId, at: safeIndex)
        }
        publishSnapshot()
    }
    
    internal func assignSampleToTrack(trackId: UUID, sample: AudioSample) {
        sequencerModel.tracks[trackId]?.sample = sample //
        publishSnapshot() //
    }
    
    internal func removeSampleFromTrack(trackId: UUID) {
        sequencerModel.tracks[trackId]?.sample = nil //
        publishSnapshot() //
    }
    
    // MARK: - Command Triggers (Called by UI)
    
    func toggleStep(trackId: UUID, stepIndex: Int) {
        let command = ToggleStepCommand(trackId: trackId, stepIndex: stepIndex, viewModel: self) //
        undoRedoManager.execute(command) //
    }
    
    func executeAddTrack() {
        let newTrack = SequencerTrack(numSteps: sequencerModel.sequenceLength)
        let command = AddTrackCommand(track: newTrack, viewModel: self)
        undoRedoManager.execute(command)
    }
    
    func executeRemoveTrack(trackId: UUID) {
        guard let track = sequencerModel.tracks[trackId],
              let index = sequencerModel.trackOrder.firstIndex(of: trackId) else { return }
        
        let command = DeleteTrackCommand(trackId: trackId, trackBackup: track, originalIndex: index, viewModel: self)
        undoRedoManager.execute(command)
    }
    
    func executeAddSample(trackId: UUID, newSample: AudioSample) {
        let previousSample = sequencerModel.tracks[trackId]?.sample
        let command = AddSampleCommand(trackId: trackId, newSample: newSample, previousSample: previousSample, viewModel: self)
        undoRedoManager.execute(command)
    }
    
    func executeRemoveSample(trackId: UUID) {
        guard let sampleBackup = sequencerModel.tracks[trackId]?.sample else { return }
        let command = DeleteSampleCommand(trackId: trackId, sampleBackup: sampleBackup, viewModel: self)
        undoRedoManager.execute(command)
    }
    
    // MARK: - Utilities & Grid Sizing
    
    func changeSequenceLength(to newLength: Int) {
        let currentLength = sequencerModel.sequenceLength
        guard newLength != currentLength else { return }
        
        // Loop through every track and resize its boolean array
        for (trackId, track) in sequencerModel.tracks {
            var updatedTrack = track
            
            if newLength > currentLength {
                // Grow: pad with false
                let padding = Array(repeating: false, count: newLength - currentLength)
                updatedTrack.steps.append(contentsOf: padding)
            } else {
                // Shrink: truncate
                updatedTrack.steps = Array(updatedTrack.steps.prefix(newLength))
            }
            sequencerModel.tracks[trackId] = updatedTrack
        }
        
        sequencerModel.sequenceLength = newLength
        if currentStep >= newLength {
            currentStep = 0
        }
        publishSnapshot()
    }
    
    func incrementBPM() { if bpm < 300 { bpm += 1 } } //
    func decrementBPM() { if bpm > 40 { bpm -= 1 } } //
    
    func undo() { undoRedoManager.undo() } //
    func redo() { undoRedoManager.redo() } //
    
    func isStepActive(trackId: UUID, stepIndex: Int) -> Bool {
        return sequencerModel.tracks[trackId]?.steps[stepIndex] ?? false //
    }
}
