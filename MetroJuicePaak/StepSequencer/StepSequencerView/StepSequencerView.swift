//
//  StepSequencerView.swift
//  MetroJuicePaak
//
//  Created by Edwin Wong on 27/03/2026.
//

import SwiftUI

struct StepSequencerView: View {
    @State var viewModel: StepSequencerViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            
            // MARK: - Top Toolbar
            HStack(spacing: 16) {
                ToolbarButton(
                    icon: viewModel.isPlaying ? "stop.fill" : "play.fill",
                    action: { viewModel.togglePlayback() },
                    color: viewModel.isPlaying ? .red : .green
                )
                
                Spacer()
                
                ToolbarButton(
                    icon: "arrow.uturn.backward",
                    action: { viewModel.undo() }
                )
                
                ToolbarButton(
                    icon: "arrow.uturn.forward",
                    action: { viewModel.redo() }
                )
                
                ToolbarButton(
                    icon: "plus",
                    action: { viewModel.executeAddTrack() },
                    color: .cyan
                )
            }
            .padding(.horizontal)
            
            // MARK: - Sequencer Grid
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    
                    // 🟢 Look how clean this is with an Array!
                    ForEach(viewModel.sequencerModel.tracks) { track in
                        HStack(spacing: 12) {
                            
                            // 1. The Track Controller (Name & Assignment)
                            TrackHeaderView(track: track, viewModel: viewModel)
                            
                            // 2. The Step Grid
                            ForEach(0..<track.steps.count, id: \.self) { stepIndex in
                                StepButton(
                                    isActive: track.steps[stepIndex],
                                    isCurrentStep: viewModel.isPlaying && viewModel.currentStep == stepIndex,
                                    action: {
                                        viewModel.executeToggleStep(trackId: track.id, stepIndex: stepIndex)
                                    }
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
            
            Spacer()
        }
        .padding(.top)
        // A dark background to make the cyan buttons pop
        .background(Color(white: 0.1).edgesIgnoringSafeArea(.all))
    }
}
