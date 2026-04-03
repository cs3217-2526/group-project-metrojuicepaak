//
//  SequencerTrack.swift
//  MetroJuicePaak
//
//  Created by Edwin Wong on 23/03/2026.
//

import Foundation

struct SequencerTrack: Identifiable, Codable, Equatable {
    var id: UUID { trackId }
    let trackId: UUID
    var sample: AudioSample?
    
    var steps: [Bool]
    
    init(trackId: UUID = UUID(), sample: AudioSample? = nil, numSteps: Int = 16) {
        self.trackId = trackId
        self.sample = sample
        self.steps = Array(repeating: false, count: numSteps)
    }
}
