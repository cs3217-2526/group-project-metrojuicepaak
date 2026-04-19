//
//  DeleteSampleCommand.swift
//  MetroJuicePaak
//
//  Created by Edwin Wong on 14/04/2026.
//

import Foundation

class DeleteSampleCommand: Command {
    private let trackId: UUID
    private let sampleIDBackup: ObjectIdentifier
    private weak var viewModel: StepSequencerViewModel?
    
    init(trackId: UUID, sampleIDBackup: ObjectIdentifier, viewModel: StepSequencerViewModel) {
        self.trackId = trackId
        self.sampleIDBackup = sampleIDBackup
        self.viewModel = viewModel
    }
    
    func execute() {
        viewModel?.removeSampleFromTrack(trackId: trackId)
    }
    
    func undo() {
        viewModel?.assignSampleToTrack(trackId: trackId, sampleID: sampleIDBackup)
    }
}
