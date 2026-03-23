//
//  SamplerViewModel.swift
//  MetroJuicePaak
//
//  Created by Noah Ang Shi Hern on 22/3/26.
//

import Foundation
import Observation

@Observable
class SamplerViewModel {
    private let audioService: AudioService
    
    private(set) var pads: [UUID: SamplerPad] = [:]
    
    var isRecording: Bool = false
    var isPlaying: Bool = false
    
    init(audioService: AudioService) {
        
        self.audioService = audioService
        
        // Create initial pads
        let initialPads = (0..<16).map { _ in
            SamplerPad(id: UUID())
        }
        
        // Store in dictionary
        pads = Dictionary(uniqueKeysWithValues: initialPads.map { ($0.id, $0) })
    }
    
    // MARK: - Public API for SamplerPads
    
    func handlePadPressed(_ padId: UUID) {
        guard let pad = pads[padId] else { return }
        
        if pad.isSampleLoaded {
            // TODO: implement startPlayback(for: padId)
        } else {
            if isRecording {
                return
            } else {
                // TODO: implement startRecording(for: padId)
            }
        }
    }
    
    func handlePadReleased(_ padId: UUID) {
        guard let pad = pads[padId] else { return }
        if pad.isSampleLoaded {
            //TODO: implement stopPlayback(for: padId)
        } else {
            //TODO: implememt stopRecording(for: padId)
        }
    }
}



