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
    // MARK: - State
    var sequencerModel: StepSequencerModel
    
    // 🟢 NEW: Directly injecting the strictly-scoped readable protocol
    let repository: ReadableAudioSampleRepository
    private let musicEngine: MusicEngine
    private let undoRedoManager = UndoRedoManager()
    
    var isPlaying: Bool = false
    var currentStep: Int = 0
    
    // MARK: - Initialization
    init(repository: ReadableAudioSampleRepository, musicEngine: MusicEngine) {
        self.repository = repository
        self.musicEngine = musicEngine
        self.sequencerModel = StepSequencerModel()
    }
    
    // MARK: - The Audio Engine Bridge (Snapshot)
    
    private func publishSnapshot() {
        var engineTracks: [UUID: EngineTrack] = [:]
        
        for track in sequencerModel.tracks {
            var pureSample: AudioSample? = nil
            
            // 🟢 NEW: Query the injected protocol safely using ObjectIdentifier
            if let sampleID = track.sampleID,
               let playable = repository.getPlayableSample(for: sampleID) as? AudioSample {
                pureSample = playable
            }
            
            // Package the frozen values for the background thread
            engineTracks[track.id] = EngineTrack(sample: pureSample, steps: track.steps)
        }
        
        let snapshot = SequencerSnapshot(
            tracks: engineTracks,
            stepCount: sequencerModel.stepCount,
            bpm: sequencerModel.bpm
        )
        musicEngine.apply(snapshot: snapshot)
    }
    
    // MARK: - Playback Controls
    
    func togglePlayback() {
        isPlaying.toggle()
        if isPlaying {
            publishSnapshot() // Ensure engine has latest data before starting
            musicEngine.startSequencer()
        } else {
            musicEngine.stopSequencer()
        }
    }
    
    // MARK: - Tempo / Transport Controls
    
    func increaseBPM() {
        let currentBPM = sequencerModel.bpm
        // Clamp to a reasonable maximum tempo
        if currentBPM < 300 {
            sequencerModel.bpm = currentBPM + 1
            publishSnapshot() // Instantly updates the audio engine's lookahead math
        }
    }
    
    func decreaseBPM() {
        let currentBPM = sequencerModel.bpm
        // Clamp to a reasonable minimum tempo
        if currentBPM > 40 {
            sequencerModel.bpm = currentBPM - 1
            publishSnapshot() // Instantly updates the audio engine's lookahead math
        }
    }
    
    // MARK: - Target Mutations (Called by Commands)
    
    internal func mutateStep(trackId: UUID, stepIndex: Int) {
        guard let index = sequencerModel.tracks.firstIndex(where: { $0.id == trackId }) else { return }
        sequencerModel.tracks[index].steps[stepIndex].toggle()
        publishSnapshot()
    }
    
    internal func insertTrack(_ track: SequencerTrack, at index: Int) {
        // Safe array insertion
        let safeIndex = min(max(index, 0), sequencerModel.tracks.count)
        sequencerModel.tracks.insert(track, at: safeIndex)
        publishSnapshot()
    }
    
    internal func removeTrack(id: UUID) {
        guard let index = sequencerModel.tracks.firstIndex(where: { $0.id == id }) else { return }
        sequencerModel.tracks.remove(at: index)
        publishSnapshot()
    }
    
    internal func assignSampleToTrack(trackId: UUID, sampleID: ObjectIdentifier) {
        guard let index = sequencerModel.tracks.firstIndex(where: { $0.id == trackId }) else { return }
        sequencerModel.tracks[index].sampleID = sampleID
        publishSnapshot()
    }
    
    internal func removeSampleFromTrack(trackId: UUID) {
        guard let index = sequencerModel.tracks.firstIndex(where: { $0.id == trackId }) else { return }
        sequencerModel.tracks[index].sampleID = nil
        publishSnapshot()
    }
    
    internal func setStepCount(_ newStepCount: Int, stepBackups: [UUID: [Bool]]? = nil) {
        let currentStepCount = sequencerModel.stepCount
        guard newStepCount != currentStepCount || stepBackups != nil else { return }
        
        sequencerModel.stepCount = newStepCount
        
        // Loop directly over the array of track classes
        for track in sequencerModel.tracks {
            
            // 1. If the user hit Undo, restore the exact pattern from memory
            if let backup = stepBackups?[track.id] {
                track.steps = backup
                continue
            }
            
            // 2. Otherwise, run your stretching/compressing algorithm
            var newSteps = Array(repeating: false, count: newStepCount)
            
            if newStepCount > currentStepCount {
                // GROWING (e.g., 16 -> 32)
                for oldIndex in 0..<currentStepCount {
                    let newIndex = Int(round(Double(oldIndex) * Double(newStepCount) / Double(currentStepCount)))
                    if newIndex < newStepCount {
                        newSteps[newIndex] = track.steps[oldIndex]
                    }
                }
            } else {
                // SHRINKING (e.g., 16 -> 8)
                for newIndex in 0..<newStepCount {
                    let oldIndex = Int(round(Double(newIndex) * Double(currentStepCount) / Double(newStepCount)))
                    if oldIndex < currentStepCount {
                        newSteps[newIndex] = track.steps[oldIndex]
                    }
                }
            }
            
            // Because 'track' is a class, we just assign it directly!
            // No need to copy into an 'updatedTrack' struct.
            track.steps = newSteps
        }
        
        // Safety check to prevent the playhead from jumping out of bounds
        if currentStep >= newStepCount {
            currentStep = 0
        }
        
        publishSnapshot()
    }
    
    // MARK: - Command Triggers (Called by the UI)
    
    func executeToggleStep(trackId: UUID, stepIndex: Int) {
        let command = ToggleStepCommand(trackId: trackId, stepIndex: stepIndex, viewModel: self)
        undoRedoManager.execute(command)
    }
    
    func executeAddTrack() {
        let newTrack = SequencerTrack(defaultStepCount: sequencerModel.stepCount)
        let command = AddTrackCommand(track: newTrack, viewModel: self)
        undoRedoManager.execute(command)
    }
    
    func executeRemoveTrack(trackId: UUID) {
        guard let index = sequencerModel.tracks.firstIndex(where: { $0.id == trackId }) else { return }
        let trackBackup = sequencerModel.tracks[index]
        let command = DeleteTrackCommand(trackId: trackId, trackBackup: trackBackup, originalIndex: index, viewModel: self)
        undoRedoManager.execute(command)
    }
    
    func executeAssignSample(trackId: UUID, sampleID: ObjectIdentifier) {
        guard let index = sequencerModel.tracks.firstIndex(where: { $0.id == trackId }) else { return }
        let previousSampleID = sequencerModel.tracks[index].sampleID
        
        let command = AddSampleCommand(trackId: trackId, newSampleID: sampleID, previousSampleID: previousSampleID, viewModel: self)
        undoRedoManager.execute(command)
    }
    
    func executeRemoveSample(trackId: UUID) {
        guard let index = sequencerModel.tracks.firstIndex(where: { $0.id == trackId }) else { return }
        guard let sampleIDBackup = sequencerModel.tracks[index].sampleID else { return }
        
        let command = DeleteSampleCommand(trackId: trackId, sampleIDBackup: sampleIDBackup, viewModel: self)
        undoRedoManager.execute(command)
    }
    
    func executeChangeStepCount(to newCount: Int) {
        guard newCount != sequencerModel.stepCount else { return }
        
        // Backup the current arrays for Undo functionality
        var oldSteps: [UUID: [Bool]] = [:]
        for track in sequencerModel.tracks {
            oldSteps[track.id] = track.steps
        }
        
        let command = ChangeStepCountCommand(
            oldStepCount: sequencerModel.stepCount,
            newStepCount: newCount,
            oldSteps: oldSteps,
            viewModel: self
        )
        undoRedoManager.execute(command)
    }
    
    // MARK: - Undo/Redo Pass-Through
    func undo() { undoRedoManager.undo() }
    func redo() { undoRedoManager.redo() }
}
