//
//  SequencerTrack.swift
//  MetroJuicePaak
//
//  Created by Edwin Wong on 23/03/2026.
//

import Foundation

struct SequencerTrack: Identifiable, Codable {
    let id: UUID
    var padID: UUID
    
    var steps: [Bool]
    
    init(id: UUID = UUID(), padID: UUID, numSteps: Int = 16) {
        self.id = id
        self.padID = padID
        self.steps = Array(repeating: false, count: numSteps)
    }
}
