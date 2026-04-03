//
//  AddSampleCommand.swift
//  MetroJuicePaak
//
//  Created by Edwin Wong on 04/04/2026.
//

import Foundation

class AddSampleCommand: Command {
    private let trackId: UUID
    private let newSample: AudioSample
    private let previousSample: AudioSample?
    private weak var viewModel: StepSequencerViewModel?
    
    init(trackId: UUID, newSample: AudioSample, previousSample: AudioSample?, viewModel: StepSequencerViewModel) {
        self.trackId = trackId
        self.newSample = newSample
        self.previousSample = previousSample
        self.viewModel = viewModel
    }
    
    func execute() {
        viewModel?.assignSampleToTrack(trackId: trackId, sample: newSample)
    }
    
    func undo() {
        if let previous = previousSample {
            viewModel?.assignSampleToTrack(trackId: trackId, sample: previous)
        } else {
            viewModel?.removeSampleFromTrack(trackId: trackId)
        }
    }
}
