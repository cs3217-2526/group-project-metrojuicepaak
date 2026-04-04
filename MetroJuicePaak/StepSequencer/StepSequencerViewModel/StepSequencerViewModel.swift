//
//  StepSequencerViewModel.swift
//  MetroJuicePaak
//
//  Created by Edwin Wong on 23/03/2026.
//
//
//import Foundation
//import Observation
//
//@Observable
//class SequencerViewModel {
//    private(set) var sequencerModel: StepSequencerModel
//    
//    init(pads: [SamplerPad]) {
//        let defaultLength = 16
//        let tracks = pads.map { pad in
//            SequencerTrack(padID: pad.id, numSteps: defaultLength)
//        }
//        self.sequencerModel = StepSequencerModel(tracks: tracks, sequenceLength: defaultLength)
//    }
//    
//    func toggleStep(trackIndex: Int, stepIndex: Int) {
//        guard trackIndex < sequencerModel.tracks.count,
//              stepIndex < sequencerModel.sequenceLength else { return }
//        
//        sequencerModel.tracks[trackIndex].steps[stepIndex].toggle()
//        
//        // Note: For Phase 3, this is where you will implement the Command Pattern
//        // to push this action to the Undo/Redo stack.
//    }
//    
//    func isStepActive(trackIndex: Int, stepIndex: Int) -> Bool {
//        guard trackIndex < sequencerModel.tracks.count,
//              stepIndex < sequencerModel.sequenceLength else { return false }
//        
//        return sequencerModel.tracks[trackIndex].steps[stepIndex]
//    }
//}
