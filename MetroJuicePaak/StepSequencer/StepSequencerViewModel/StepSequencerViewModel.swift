////
////  StepSequencerViewModel.swift
////  MetroJuicePaak
////
////  Created by Edwin Wong on 23/03/2026.
////
//
//import Foundation
//import Observation
//
//@Observable
//class StepSequencerViewModel {
//    private(set) var sequencerModel: StepSequencerModel
//    
//    let pads: [SamplerPad]
//    private let audioService: AudioService
//    private let undoRedoManager = UndoRedoManager()
//    
//    var isPlaying: Bool = false
//    var currentStep: Int = 0
//    var bpm: Double = 120.0
//    private var playbackTask: Task<Void, Never>?
//    
//    let availableLengths: [Int] = [6, 8, 12, 16, 24, 32]
//    
//    var canUndo: Bool { undoRedoManager.canUndo }
//    var canRedo: Bool { undoRedoManager.canRedo }
//    
//    init(pads: [SamplerPad], audioService: AudioService) {
//        self.pads = pads
//        self.audioService = audioService
//        
//        let defaultLength = 16
//        self.sequencerModel = StepSequencerModel(tracks: [], sequenceLength: defaultLength)
//    }
//    
//    // MARK: - Sequence Length Management
//    
//    func changeSequenceLength(to newLength: Int) {
//        let currentLength = sequencerModel.sequenceLength
//        guard newLength != currentLength else { return }
//        
//        // Resize the steps array in every existing track first
//        for i in 0..<sequencerModel.tracks.count {
//            if newLength > currentLength {
//                // Pad with false (empty steps)
//                let padding = Array(repeating: false, count: newLength - currentLength)
//                sequencerModel.tracks[i].steps.append(contentsOf: padding)
//            } else {
//                // Truncate to the new shorter length
//                sequencerModel.tracks[i].steps = Array(sequencerModel.tracks[i].steps.prefix(newLength))
//            }
//        }
//        
//        // Update the model's sequence length so the UI updates
//        sequencerModel.sequenceLength = newLength
//        
//        // Prevent crashes if the playhead was out of the new bounds
//        if currentStep >= newLength {
//            currentStep = 0
//        }
//    }
//    
//    // MARK: - Pad Availability Logic
//    
//    var availablePadsToAdd: [SamplerPad] {
//        let usedPadIDs = Set(sequencerModel.tracks.map { $0.padID })
//        return pads.filter { !usedPadIDs.contains($0.id) }
//    }
//    
//    var canAddMoreTracks: Bool {
//        sequencerModel.tracks.count < 16 && !availablePadsToAdd.isEmpty
//    }
//    
//    // MARK: - Track Management
//    
//    func addTrack(for padID: UUID) {
//        guard !sequencerModel.tracks.contains(where: { $0.padID == padID }),
//              sequencerModel.tracks.count < 16 else { return }
//        
//        let newTrack = SequencerTrack(padID: padID, numSteps: sequencerModel.sequenceLength)
//        sequencerModel.tracks.append(newTrack)
//    }
//    
//    func removeTrack(at index: Int) {
//        guard index < sequencerModel.tracks.count else { return }
//        sequencerModel.tracks.remove(at: index)
//    }
//    
//    func updateTrackPad(trackIndex: Int, newPadID: UUID) {
//        guard trackIndex < sequencerModel.tracks.count else { return }
//        guard !sequencerModel.tracks.contains(where: { $0.padID == newPadID }) else { return }
//        
//        sequencerModel.tracks[trackIndex].padID = newPadID
//    }
//    
//    func padNumber(for padID: UUID) -> Int {
//        guard let index = pads.firstIndex(where: { $0.id == padID }) else { return 0 }
//        return index + 1
//    }
//    
//    // MARK: - Editing via Command Pattern
//    
//    func toggleStep(trackIndex: Int, stepIndex: Int) {
//        let command = ToggleStepCommand(trackIndex: trackIndex, stepIndex: stepIndex, viewModel: self)
//        undoRedoManager.execute(command)
//    }
//    
//    func undo() {
//        undoRedoManager.undo()
//    }
//    
//    func redo() {
//        undoRedoManager.redo()
//    }
//    
//    internal func mutateStep(trackIndex: Int, stepIndex: Int) {
//        guard trackIndex < sequencerModel.tracks.count,
//              stepIndex < sequencerModel.sequenceLength else { return }
//        
//        sequencerModel.tracks[trackIndex].steps[stepIndex].toggle()
//    }
//    
//    func isStepActive(trackIndex: Int, stepIndex: Int) -> Bool {
//        guard trackIndex < sequencerModel.tracks.count,
//              stepIndex < sequencerModel.sequenceLength else { return false }
//        return sequencerModel.tracks[trackIndex].steps[stepIndex]
//    }
//    
//    // MARK: - Playback Engine
//    
//    func togglePlayback() {
//        if isPlaying {
//            stop()
//        } else {
//            play()
//        }
//    }
//    
//    private func play() {
//        isPlaying = true
//        currentStep = 0
//        
//        playbackTask = Task {
//            while isPlaying && !Task.isCancelled {
//                await playSoundsForCurrentStep()
//                
//                // Calculate sleep time for 16th notes based on BPM
//                // 60 seconds / BPM = 1 beat (quarter note). Divide by 4 for 16th notes.
//                let secondsPerStep = (60.0 / bpm) / 4.0
//                let nanoseconds = UInt64(secondsPerStep * 1_000_000_000)
//                
//                try? await Task.sleep(nanoseconds: nanoseconds)
//                
//                if !Task.isCancelled {
//                    // Move to next step, loop back to 0 at the end
//                    currentStep = (currentStep + 1) % sequencerModel.sequenceLength
//                }
//            }
//        }
//    }
//    
//    private func stop() {
//        isPlaying = false
//        playbackTask?.cancel()
//        playbackTask = nil
//        currentStep = 0
//    }
//    
//    private func playSoundsForCurrentStep() async {
//        for (index, track) in sequencerModel.tracks.enumerated() {
//            if track.steps[currentStep] {
//                // Find the pad associated with this track
//                let pad = pads[index]
//                if pad.isSampleLoaded, let sampleID = pad.sampleID {
//                    // Trigger the audio service concurrently so multiple tracks can play at once
//                    Task {
//                        await audioService.playAudio(identifier: sampleID)
//                    }
//                }
//            }
//        }
//    }
//    
//    // MARK: - BPM Management
//        
//    func incrementBPM() {
//        // Cap the maximum BPM at 300
//        if bpm < 300 {
//            bpm += 1
//        }
//    }
//    
//    func decrementBPM() {
//        // Floor the minimum BPM at 40
//        if bpm > 40 {
//            bpm -= 1
//        }
//    }
//}
