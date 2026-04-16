//
//  SequencerTrack.swift
//  MetroJuicePaak
//
//  Created by Edwin Wong on 23/03/2026.
//

import Foundation
import Observation

@Observable
class SequencerTrack: Identifiable {
    let id: UUID
    
    var sampleID: ObjectIdentifier?
    
    var steps: [Bool]
    
    init(id: UUID = UUID(), sampleID: ObjectIdentifier? = nil, defaultStepCount: Int = 16) {
        self.id = id
        self.sampleID = sampleID
        self.steps = Array(repeating: false, count: defaultStepCount)
    }
}
