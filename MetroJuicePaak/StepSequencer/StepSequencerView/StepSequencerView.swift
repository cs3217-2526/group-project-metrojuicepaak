//
//  StepSequencerView.swift
//  MetroJuicePaak
//
//  Created by Edwin Wong on 27/03/2026.
//

import SwiftUI

struct StepSequencerView: View {
    @Bindable var viewModel: StepSequencerViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            topToolbar()
            sequencerGrid()
            Spacer()
        }
        .padding(.top)
        .background(Color.black.edgesIgnoringSafeArea(.all))
        .alert(
            "Tempo Limit Reached",
            isPresented: Binding(
                get: { viewModel.activeWarning != nil },
                set: { isPresenting in
                    if !isPresenting { viewModel.activeWarning = nil }
                }
            ),
            presenting: viewModel.activeWarning
        ) { warning in
            Button("Got it", role: .cancel) { }
        } message: { warning in
            Text(warning.localizedDescription)
        }
    }
    
    // MARK: - UI Components
    
    @ViewBuilder
    private func topToolbar() -> some View {
        HStack(spacing: 16) {
            playbackControl()
            stepsIndicator()
            bpmControl()
            Spacer()
            undoRedoControls()
        }
        .padding()
    }
    
    @ViewBuilder
    private func sequencerGrid() -> some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 2) {
                
                ForEach(viewModel.sequencerModel.tracks) { track in
                    trackRow(for: track)
                }
                
                addTrackButton()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
        }
    }
    
    // MARK: - Helper Functions
    
    @ViewBuilder
    private func trackRow(for track: SequencerTrack) -> some View {
        HStack(spacing: 2) {
            TrackHeaderView(track: track, viewModel: viewModel)
            
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
    
    @ViewBuilder
    private func playbackControl() -> some View {
        ToolbarButton(
            icon: viewModel.isPlaying ? "stop.fill" : "play.fill",
            action: { viewModel.togglePlayback() },
            color: viewModel.isPlaying ? .red : .green
        )
    }
    
    @ViewBuilder
    private func stepsIndicator() -> some View {
        Menu {
            Button("8 Steps") { viewModel.executeChangeStepCount(to: 8) }
            Button("16 Steps") { viewModel.executeChangeStepCount(to: 16) }
            Button("32 Steps") { viewModel.executeChangeStepCount(to: 32) }
        } label: {
            HStack(spacing: 4) {
                Text("\(viewModel.sequencerModel.stepCount) Steps")
                Image(systemName: "chevron.up.chevron.down")
            }
            .font(.caption.bold())
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(Color(white: 0.15))
            .cornerRadius(6)
        }
    }
    
    @ViewBuilder
    private func bpmControl() -> some View {
        HStack(spacing: 16) {
            Button(action: { viewModel.decreaseBPM() }) {
                Image(systemName: "minus").foregroundColor(Color(white: 0.6))
            }
            Text("\(Int(viewModel.sequencerModel.bpm)) BPM")
                .font(.caption.bold())
                .foregroundColor(Color(red: 0.0, green: 0.8, blue: 0.9))
            Button(action: { viewModel.increaseBPM() }) {
                Image(systemName: "plus").foregroundColor(Color(white: 0.6))
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(Color(white: 0.15))
        .cornerRadius(6)
    }
    
    @ViewBuilder
    private func undoRedoControls() -> some View {
        HStack(spacing: 8) {
            ToolbarButton(icon: "arrow.uturn.backward", action: { viewModel.undo() })
            ToolbarButton(icon: "arrow.uturn.forward", action: { viewModel.redo() })
        }
    }
    
    @ViewBuilder
    private func addTrackButton() -> some View {
        Button(action: {
            viewModel.executeAddTrack()
        }) {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                Text("Add Track")
            }
            .font(.caption.bold())
            .foregroundColor(Color(red: 0.0, green: 0.8, blue: 0.9))
            .frame(width: 150, height: 44)
            .background(Color(white: 0.15))
            .cornerRadius(4)
        }
        .padding(.top, 8)
    }
}
