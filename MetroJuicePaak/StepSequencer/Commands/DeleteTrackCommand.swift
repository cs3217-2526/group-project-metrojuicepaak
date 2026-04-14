//
//  DeleteTrackCommand.swift
//  MetroJuicePaak
//
//  Created by Edwin Wong on 14/04/2026.
//

import Foundation

class DeleteTrackCommand: Command {
    private let trackId: UUID
    private let trackBackup: SequencerTrack
    private let originalIndex: Int
    private weak var viewModel: StepSequencerViewModel?
    
    init(trackId: UUID, trackBackup: SequencerTrack, originalIndex: Int, viewModel: StepSequencerViewModel) {
        self.trackId = trackId
        self.trackBackup = trackBackup
        self.originalIndex = originalIndex
        self.viewModel = viewModel
    }
    
    func execute() {
        viewModel?.removeTrack(id: trackId)
    }
    
    func undo() {
        // Restore the track to its exact previous location in the array
        viewModel?.insertTrack(trackBackup, at: originalIndex)
    }
}
