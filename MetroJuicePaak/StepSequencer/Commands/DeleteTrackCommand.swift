//
//  DeleteTrackCommand.swift
//  MetroJuicePaak
//
//  Created by Edwin Wong on 04/04/2026.
//

import Foundation

class DeleteTrackCommand: Command {
    private let trackId: UUID
    private let trackBackup: SequencerTrack
    private let originalIndex: Int // Crucial for putting it back in the right spot!
    private weak var viewModel: StepSequencerViewModel?
    
    init(trackId: UUID, trackBackup: SequencerTrack, originalIndex: Int, viewModel: StepSequencerViewModel) {
        self.trackId = trackId
        self.trackBackup = trackBackup
        self.originalIndex = originalIndex
        self.viewModel = viewModel
    }
    
    func execute() {
        viewModel?.removeTrack(at: trackId)
    }
    
    func undo() {
        viewModel?.restoreTrack(trackBackup, at: originalIndex)
    }
}
