//
//  AddTrackCommand.swift
//  MetroJuicePaak
//
//  Created by Edwin Wong on 14/04/2026.
//

class AddTrackCommand: Command {
    private let track: SequencerTrack
    private weak var viewModel: StepSequencerViewModel?
    
    init(track: SequencerTrack, viewModel: StepSequencerViewModel) {
        self.track = track
        self.viewModel = viewModel
    }
    
    func execute() {
        let endPosition = viewModel?.sequencerModel.tracks.count ?? 0
        viewModel?.insertTrack(track, at: endPosition)
    }
    
    func undo() {
        viewModel?.removeTrack(id: track.id)
    }
}
