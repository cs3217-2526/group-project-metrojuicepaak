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
    
    private let sessionManager: AudioSampleRepositoryViewModel
    private let musicEngine: MusicEngine
    private let undoRedoManager = UndoRedoManager()
    
    var isPlaying: Bool = false
    var currentStep: Int = 0
    
    var bpm: Double {
        get { sequencerModel.bpm }
        set {
            sequencerModel.bpm = newValue
            publishSnapshot()
        }
    }
    
    let availableStepCounts: [Int] = [8, 16, 32]
    
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
            stop()
        } else {
            play()
        }
    }
    
    private func play() {
        isPlaying = true
        currentStep = 0
        publishSnapshot()
        musicEngine.startSequencer()
    }
    
    private func stop() {
        isPlaying = false
        musicEngine.stopSequencer()
        currentStep = 0
    }
    
    // MARK: - Target Mutations (Called by Commands)
    
    internal func mutateStep(trackId: UUID, stepIndex: Int) {
        guard sequencerModel.tracks[trackId] != nil,
              stepIndex < sequencerModel.stepCount else { return }
        
        sequencerModel.tracks[trackId]?.steps[stepIndex].toggle()
        publishSnapshot()
    }
    
    internal func addTrack(track: SequencerTrack) {
        sequencerModel.tracks[track.trackId] = track
        if !sequencerModel.trackOrder.contains(track.trackId) {
            sequencerModel.trackOrder.append(track.trackId)
        }
        publishSnapshot()
    }
    
    internal func removeTrack(at trackId: UUID) {
        sequencerModel.tracks.removeValue(forKey: trackId)
        sequencerModel.trackOrder.removeAll { $0 == trackId }
        publishSnapshot()
    }
    
    internal func restoreTrack(_ track: SequencerTrack, at index: Int) {
        sequencerModel.tracks[track.trackId] = track
        
        if !sequencerModel.trackOrder.contains(track.trackId) {
            let safeIndex = min(max(0, index), sequencerModel.trackOrder.count)
            sequencerModel.trackOrder.insert(track.trackId, at: safeIndex)
        }
        publishSnapshot()
    }
    
    internal func assignSampleToTrack(trackId: UUID, sample: AudioSample) {
        sequencerModel.tracks[trackId]?.sample = sample
        publishSnapshot()
    }
    
    internal func removeSampleFromTrack(trackId: UUID) {
        sequencerModel.tracks[trackId]?.sample = nil
        publishSnapshot()
    }
    
    // MARK: - Command Triggers (Called by UI)
    
    func toggleStep(trackId: UUID, stepIndex: Int) {
        let command = ToggleStepCommand(trackId: trackId, stepIndex: stepIndex, viewModel: self)
        undoRedoManager.execute(command)
    }
    
    func executeAddTrack() {
        let newTrack = SequencerTrack(defaultStepCount: sequencerModel.stepCount)
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
    
    func changeStepCount(to newStepCount: Int) {
        let currentStepCount = sequencerModel.stepCount
        guard newStepCount != currentStepCount else { return }
        
        for (trackId, track) in sequencerModel.tracks {
            var updatedTrack = track //
            var newSteps = Array(repeating: false, count: newStepCount)
            
            if newStepCount > currentStepCount {
                // GROWING (e.g., 16 -> 32)
                // Stretch the pattern out. oldIndex 1 becomes newIndex 2, leaving gaps of `false`.
                for oldIndex in 0..<currentStepCount {
                    let newIndex = Int(round(Double(oldIndex) * Double(newStepCount) / Double(currentStepCount)))
                    if newIndex < newStepCount {
                        newSteps[newIndex] = track.steps[oldIndex]
                    }
                }
            } else {
                // SHRINKING (e.g., 16 -> 8)
                // Compress the pattern. newIndex 1 pulls from oldIndex 2, effectively deleting oldIndex 1.
                for newIndex in 0..<newStepCount {
                    let oldIndex = Int(round(Double(newIndex) * Double(currentStepCount) / Double(newStepCount)))
                    if oldIndex < currentStepCount {
                        newSteps[newIndex] = track.steps[oldIndex]
                    }
                }
            }
            
            updatedTrack.steps = newSteps
            sequencerModel.tracks[trackId] = updatedTrack
        }
        
        sequencerModel.stepCount = newStepCount
        
        if currentStep >= newStepCount {
            currentStep = 0
        }
        publishSnapshot()
    }
    
    func incrementBPM() { if bpm < 300 { bpm += 1 } }
    func decrementBPM() { if bpm > 40 { bpm -= 1 } }
    
    func undo() { undoRedoManager.undo() }
    func redo() { undoRedoManager.redo() }
    
    func isStepActive(trackId: UUID, stepIndex: Int) -> Bool {
        return sequencerModel.tracks[trackId]?.steps[stepIndex] ?? false
    }
}
