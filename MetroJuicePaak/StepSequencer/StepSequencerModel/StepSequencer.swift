//
//  StepSequencer.swift
//  MetroJuicePaak
//
//  Created by Edwin Wong on 23/03/2026.
//

import Foundation

struct StepSequencerModel {
    var tracks: [SequencerTrack]
    
    var stepCount: Int
    var bpm: Double
    
    init(tracks: [SequencerTrack] = [], stepCount: Int = 16, bpm: Double = 120.0) {
        self.tracks = tracks
        self.stepCount = stepCount
        self.bpm = bpm
    }
}
