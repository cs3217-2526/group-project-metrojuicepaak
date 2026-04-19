//
//  AudioEngineSnapshot.swift
//  MetroJuicePaak
//
//  Created by Edwin Wong on 14/04/2026.
//

import Foundation

/// A pure-data, lock-free representation of a single track.
/// This contains no classes, no @Observable wrappers, and no UI logic.
struct EngineTrack {
    let sample: AudioSample? // The pure domain model from the repository
    let steps: [Bool]        // A frozen copy of the boolean array
}

/// The immutable payload handed across the thread boundary to the MusicEngine.
struct SequencerSnapshot {
    // We use a dictionary here so the audio engine can do lightning-fast O(1) lookups
    let tracks: [UUID: EngineTrack]
    
    let stepCount: Int
    let bpm: Double
}
