//
//  StepSequencer.swift
//  MetroJuicePaak
//
//  Created by Edwin Wong on 23/03/2026.
//

import Foundation

struct StepSequencerModel: Codable {
    var tracks: [SequencerTrack]
    
    var sequenceLength: Int
    
    init(tracks: [SequencerTrack] = [], sequenceLength: Int = 16) {
        self.tracks = tracks
        self.sequenceLength = sequenceLength
    }
}
