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
    
    init(audioService: AudioService = AudioService()) {
        
        self.audioService = audioService
        
        // Create initial pads
        let initialPads = (0..<16).map { _ in
            SamplerPad(id: UUID())
        }
        
        // Store in dictionary
        pads = Dictionary(uniqueKeysWithValues: initialPads.map { ($0.id, $0) })
    }
    
    // MARK: - Public API (Actions - Business Logic)
    
    func handlePadPressed(_ padId: UUID) {
        guard let pad = pads[padId] else { return }
        
        if pad.isSampleLoaded {
            //startPlayback(for: padId)
        } else {
            //startRecording(for: padId)
        }
    }
    
    func handlePadReleased(_ padId: UUID) {
        guard let pad = pads[padId] else { return }
        if pad.isSampleLoaded {
            //stopPlayback(for: padId)
        } else {
            //stopRecording(for: padId)
        }
    }
}
// MARK: - Preview Helpers
#if DEBUG
extension SamplerViewModel {
    /// Creates a mock ViewModel for previews with no audio dependencies
    static func mockForPreview() -> SamplerViewModel {
        let viewModel = SamplerViewModel()
        return viewModel
    }
    
    /// Creates a mock ViewModel with some loaded samples for testing UI states
    static func mockWithSamples() -> SamplerViewModel {
        let viewModel = SamplerViewModel()
        // Mock loading samples on first 3 pads
        let padIds = Array(viewModel.pads.keys).prefix(3)
        for padId in padIds {
            if let pad = viewModel.pads[padId] {
                let mockURL = URL(fileURLWithPath: "/mock/sample.wav")
                pad.sample = AudioSample(url: mockURL, duration: 2.5)
            }
        }
        return viewModel
    }
}
#endif

