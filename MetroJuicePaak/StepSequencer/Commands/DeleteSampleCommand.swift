//
//  DeleteSampleCommand.swift
//  MetroJuicePaak
//
//  Created by Edwin Wong on 04/04/2026.
//

import Foundation

class DeleteSampleCommand: Command {
    private let trackId: UUID
    private let sampleBackup: AudioSample
    private weak var viewModel: StepSequencerViewModel?
    
    init(trackId: UUID, sampleBackup: AudioSample, viewModel: StepSequencerViewModel) {
        self.trackId = trackId
        self.sampleBackup = sampleBackup
        self.viewModel = viewModel
    }
    
    func execute() {
        viewModel?.removeSampleFromTrack(trackId: trackId)
    }
    
    func undo() {
        viewModel?.assignSampleToTrack(trackId: trackId, sample: sampleBackup)
    }
}
