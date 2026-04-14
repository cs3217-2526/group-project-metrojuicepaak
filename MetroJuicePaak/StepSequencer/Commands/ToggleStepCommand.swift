////
////  ToggleStepCommand.swift
////  MetroJuicePaak
////
////  Created by Edwin Wong on 27/03/2026.
////
//
//class ToggleStepCommand: Command {
//    private let trackIndex: Int
//    private let stepIndex: Int
//    private weak var viewModel: StepSequencerViewModel?
//    
//    init(trackIndex: Int, stepIndex: Int, viewModel: StepSequencerViewModel) {
//        self.trackIndex = trackIndex
//        self.stepIndex = stepIndex
//        self.viewModel = viewModel
//        // We use a keypath or direct method call. A direct closure/method approach is simpler here.
//    }
//    
//    func execute() {
//        viewModel?.mutateStep(trackIndex: trackIndex, stepIndex: stepIndex)
//    }
//    
//    func undo() {
//        // Toggling again reverses the state
//        viewModel?.mutateStep(trackIndex: trackIndex, stepIndex: stepIndex)
//    }
//}
