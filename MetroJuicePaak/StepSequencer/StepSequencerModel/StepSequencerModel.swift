//
//  StepSequencer.swift
//  MetroJuicePaak
//
//  Created by Edwin Wong on 23/03/2026.
//

import Foundation

struct StepSequencerModel: Codable {
    var tracks: [UUID: SequencerTrack]
    var trackOrder: [UUID]
    
    var stepCount: Int
    var bpm: Double
    
    init(tracks: [UUID: SequencerTrack] = [:], trackOrder: [UUID] = [], stepCount: Int = 16, bpm: Double = 120.0) {
        self.tracks = tracks
        self.trackOrder = trackOrder
        self.stepCount = stepCount
        self.bpm = bpm
    }
}

struct SequencerSnapshot {
    let tracks: [UUID: SequencerTrack]
    let bpm: Double
}
