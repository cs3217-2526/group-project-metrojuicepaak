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
    
    // MARK: - Undo/Redo Pass-Through
    func undo() { undoRedoManager.undo() }
    func redo() { undoRedoManager.redo() }
}
