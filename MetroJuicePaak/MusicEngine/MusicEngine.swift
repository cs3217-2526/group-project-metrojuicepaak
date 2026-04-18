//
//  MusicEngineProtocol.swift
//  MetroJuicePaak
//
//  Created by Edwin Wong on 04/04/2026.
//

import Foundation

protocol MusicEngine {
    func startSequencer()
    func stopSequencer()
    func apply(snapshot: SequencerSnapshot)
}
