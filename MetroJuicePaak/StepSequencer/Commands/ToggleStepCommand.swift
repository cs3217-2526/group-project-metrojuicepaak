//
//  ToggleStepCommand.swift
//  MetroJuicePaak
//
//  Created by Edwin Wong on 27/03/2026.
//

import Foundation

class ToggleStepCommand: Command {
    private let trackId: UUID
    private let stepIndex: Int
    private weak var viewModel: StepSequencerViewModel?
    
    init(trackId: UUID, stepIndex: Int, viewModel: StepSequencerViewModel) {
        self.trackId = trackId
        self.stepIndex = stepIndex
        self.viewModel = viewModel
    }
    
    func execute() {
        viewModel?.mutateStep(trackId: trackId, stepIndex: stepIndex)
    }
    
    func undo() {
        viewModel?.mutateStep(trackId: trackId, stepIndex: stepIndex)
    }
}
