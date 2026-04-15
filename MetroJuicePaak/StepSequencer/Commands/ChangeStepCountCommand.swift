//
//  ChangeStepCountCommand.swift
//  MetroJuicePaak
//
//  Created by Edwin Wong on 15/04/2026.
//

import Foundation

// MARK: - Change Step Count
class ChangeStepCountCommand: Command {
    private let oldStepCount: Int
    private let newStepCount: Int
    private let oldSteps: [UUID: [Bool]]
    private weak var viewModel: StepSequencerViewModel?
    
    init(oldStepCount: Int, newStepCount: Int, oldSteps: [UUID: [Bool]], viewModel: StepSequencerViewModel) {
        self.oldStepCount = oldStepCount
        self.newStepCount = newStepCount
        self.oldSteps = oldSteps
        self.viewModel = viewModel
    }
    
    func execute() {
        viewModel?.setStepCount(newStepCount)
    }
    
    func undo() {
        viewModel?.setStepCount(oldStepCount, stepBackups: oldSteps)
    }
}
