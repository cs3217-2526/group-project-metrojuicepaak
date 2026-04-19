//
//  SequencerSnapshot.swift
//  MetroJuicePaak
//
//  Created by Edwin Wong on 19/04/2026.
//

import Foundation

struct SequencerSnapshot {
    let tracks: [UUID: EngineTrack]
    
    let stepCount: Int
    let bpm: Double
}
