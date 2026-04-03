//
//  AddTrackCommand.swift
//  MetroJuicePaak
//
//  Created by Edwin Wong on 04/04/2026.
//

import Foundation

class AddTrackCommand: Command {
    private let track: SequencerTrack
    private weak var viewModel: StepSequencerViewModel?
    
    init(track: SequencerTrack, viewModel: StepSequencerViewModel) {
        self.track = track
        self.viewModel = viewModel
    }
    
    func execute() {
        viewModel?.addTrack(track: track)
    }
    
    func undo() {
        viewModel?.removeTrack(at: track.trackId)
    }
}
