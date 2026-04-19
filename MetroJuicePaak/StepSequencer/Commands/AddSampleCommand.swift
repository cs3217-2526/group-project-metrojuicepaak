//
//  AddSampleCommand.swift
//  MetroJuicePaak
//
//  Created by Edwin Wong on 14/04/2026.
//

import Foundation

class AddSampleCommand: Command {
    private let trackId: UUID
    private let newSampleID: ObjectIdentifier
    private let previousSampleID: ObjectIdentifier?
    private weak var viewModel: StepSequencerViewModel?
    
    init(trackId: UUID, newSampleID: ObjectIdentifier, previousSampleID: ObjectIdentifier?, viewModel: StepSequencerViewModel) {
        self.trackId = trackId
        self.newSampleID = newSampleID
        self.previousSampleID = previousSampleID
        self.viewModel = viewModel
    }
    
    func execute() {
        viewModel?.assignSampleToTrack(trackId: trackId, sampleID: newSampleID)
    }
    
    func undo() {
        if let previous = previousSampleID {
            viewModel?.assignSampleToTrack(trackId: trackId, sampleID: previous)
        } else {
            viewModel?.removeSampleFromTrack(trackId: trackId)
        }
    }
}
