//
//  MockMusicEngine.swift
//  MetroJuicePaak
//
//  Created by Edwin Wong on 18/04/2026.
//


import Foundation
@testable import MetroJuicePaak

final class MockMusicEngine: MusicEngine {
    var isRunning = false
    var latestSnapshot: SequencerSnapshot?
    
    func startSequencer() { isRunning = true }
    func stopSequencer() { isRunning = false }
    
    func apply(snapshot: SequencerSnapshot) {
        self.latestSnapshot = snapshot
    }
}