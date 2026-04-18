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
    
    let repository: ReadableAudioSampleRepository
    private let musicEngine: MusicEngine
    private let undoRedoManager = UndoRedoManager()
    
    var isPlaying: Bool = false
    var currentStep: Int = 0
    
    // MARK: - UI Playhead State
    private var playbackTimer: Timer?
    private var playbackStartTime: Date?
    
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
            
            if let sampleID = track.sampleID,
               let playable = repository.getPlayableSample(for: sampleID) as? AudioSample {
                pureSample = playable
            }
            
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
    
    private func startVisualPlayhead() {
        // Invalidate any existing timer just to be safe
        playbackTimer?.invalidate()
        playbackStartTime = Date()
        
        // Run a fast timer (approx 60fps) on the main thread to keep the UI buttery smooth
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.playbackStartTime else { return }
            
            // 1. Calculate how much time has passed since we hit play
            let elapsed = Date().timeIntervalSince(startTime)
            
            // 2. Do the BPM math to find out how long a single step is
            let secondsPerBeat = 60.0 / self.sequencerModel.bpm
            let secondsPerStep = secondsPerBeat / 4.0 // 16th notes
            
            // 3. Figure out which absolute step we are on
            let absoluteStep = Int(floor(elapsed / secondsPerStep))
            
            // 4. Wrap it around the track length (8, 16, or 32)
            let newStep = absoluteStep % self.sequencerModel.stepCount
            
            // 5. Only trigger a SwiftUI redraw if the step actually moved!
            if newStep != self.currentStep {
                self.currentStep = newStep
            }
        }
    }
    
    private func stopVisualPlayhead() {
        playbackTimer?.invalidate()
        playbackTimer = nil
        currentStep = 0
    }
    
    func togglePlayback() {
        isPlaying.toggle()
        
        if isPlaying {
            // 1. Start the hardware audio scheduler
            musicEngine.startSequencer()
            
            // 2. Start the UI playhead
            startVisualPlayhead()
        } else {
            // 1. Stop the hardware audio scheduler
            musicEngine.stopSequencer()
            
            // 2. Stop the UI playhead and reset to zero
            stopVisualPlayhead()
        }
    }
    
    // MARK: - Tempo / Transport Controls
    
    func increaseBPM() {
        let currentBPM = sequencerModel.bpm
        if currentBPM < 300 {
            sequencerModel.bpm = currentBPM + 1
            publishSnapshot()
        }
    }
    
    func decreaseBPM() {
        let currentBPM = sequencerModel.bpm
        if currentBPM > 40 {
            sequencerModel.bpm = currentBPM - 1
            publishSnapshot()
        }
    }
    
    // MARK: - Target Mutations (Called by Commands)
    
    internal func mutateStep(trackId: UUID, stepIndex: Int) {
        guard let index = sequencerModel.tracks.firstIndex(where: { $0.id == trackId }) else { return }
        sequencerModel.tracks[index].steps[stepIndex].toggle()
        publishSnapshot()
    }
    
    internal func insertTrack(_ track: SequencerTrack, at index: Int) {
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
            
            track.steps = newSteps
        }
        
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
