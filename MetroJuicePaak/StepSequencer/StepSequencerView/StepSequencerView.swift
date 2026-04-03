//
//  StepSequencerView.swift
//  MetroJuicePaak
//
//  Created by Edwin Wong on 27/03/2026.
//

import SwiftUI

struct StepSequencerView: View {
    @State private var viewModel: StepSequencerViewModel
    
    let leftColumnWidth: CGFloat = 160
    
    init(viewModel: StepSequencerViewModel) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        VStack(spacing: 0) {
            topToolbar
            
            GeometryReader { gridGeometry in
                sequencerArea(in: gridGeometry)
            }
            .background(Color.black)
        }
        .navigationBarTitleDisplayMode(.inline)
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
}

// MARK: - Subcomponents
private extension StepSequencerView {
    
    var topToolbar: some View {
        HStack {
            playbackButton
            stepCountMenu
            bpmControls
            Spacer()
            undoRedoButtons
        }
        .padding()
        .background(Color(white: 0.1))
    }
    
    func sequencerArea(in geometry: GeometryProxy) -> some View {
        let maxRows: CGFloat = 16
        let verticalSpacing: CGFloat = 4
        let rowHeight = max(10, (geometry.size.height - ((maxRows - 1) * verticalSpacing)) / maxRows)
        
        let horizontalSpacing: CGFloat = 2.0
        let totalHorizontalSpacing = CGFloat(viewModel.sequencerModel.stepCount - 1) * horizontalSpacing
        let availableGridWidth = geometry.size.width - leftColumnWidth - 16
        let stepWidth = max(1, (availableGridWidth - totalHorizontalSpacing) / CGFloat(viewModel.sequencerModel.stepCount))
        
        return HStack(alignment: .top, spacing: 4) {
            trackHeadersColumn(rowHeight: rowHeight, spacing: verticalSpacing)
            stepGridColumn(stepWidth: stepWidth, rowHeight: rowHeight, horizontalSpacing: horizontalSpacing, verticalSpacing: verticalSpacing)
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
    }
    
    func trackHeadersColumn(rowHeight: CGFloat, spacing: CGFloat) -> some View {
        VStack(spacing: spacing) {
            ForEach(viewModel.sequencerModel.trackOrder, id: \.self) { trackId in
                TrackHeaderView(trackId: trackId, viewModel: viewModel, rowHeight: rowHeight)
            }
            
            if viewModel.sequencerModel.trackOrder.count < 16 {
                addTrackButton(rowHeight: rowHeight)
            }
            Spacer(minLength: 0)
        }
        .frame(width: leftColumnWidth)
    }
    
    func stepGridColumn(stepWidth: CGFloat, rowHeight: CGFloat, horizontalSpacing: CGFloat, verticalSpacing: CGFloat) -> some View {
        VStack(spacing: verticalSpacing) {
            ForEach(viewModel.sequencerModel.trackOrder, id: \.self) { trackId in
                HStack(spacing: horizontalSpacing) {
                    ForEach(0..<viewModel.sequencerModel.stepCount, id: \.self) { stepIndex in
                        StepView(
                            isActive: viewModel.isStepActive(trackId: trackId, stepIndex: stepIndex),
                            isCurrentStep: viewModel.isPlaying && viewModel.currentStep == stepIndex,
                            width: stepWidth,
                            height: rowHeight
                        ) {
                            viewModel.toggleStep(trackId: trackId, stepIndex: stepIndex)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - UI Controls
private extension StepSequencerView {
    
    var playbackButton: some View {
        Button(action: { viewModel.togglePlayback() }) {
            Image(systemName: viewModel.isPlaying ? "stop.fill" : "play.fill")
                .font(.title2)
                .foregroundStyle(viewModel.isPlaying ? .red : .green)
                .frame(width: 44, height: 44)
                .background(Color(white: 0.15))
                .cornerRadius(8)
        }
    }
    
    var stepCountMenu: some View {
        Menu {
            ForEach(viewModel.availableStepCounts, id: \.self) { stepCount in
                Button("\(stepCount) Steps") { viewModel.changeStepCount(to: stepCount) }
            }
        } label: {
            HStack {
                Text("\(viewModel.sequencerModel.stepCount) Steps")
                    .fontWeight(.semibold)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(Color(white: 0.15))
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .padding(.leading, 8)
    }
    
    var bpmControls: some View {
        HStack(spacing: 12) {
            Button(action: { viewModel.decrementBPM() }) {
                Image(systemName: "minus")
                    .font(.body.weight(.bold))
                    .foregroundColor(.gray)
            }
            
            Text("\(Int(viewModel.bpm)) BPM")
                .font(.system(.body, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(.cyan)
                .frame(width: 80)
            
            Button(action: { viewModel.incrementBPM() }) {
                Image(systemName: "plus")
                    .font(.body.weight(.bold))
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 44)
        .background(Color(white: 0.15))
        .cornerRadius(8)
        .padding(.leading, 8)
    }
    
    var undoRedoButtons: some View {
        HStack {
            Button(action: { viewModel.undo() }) { Image(systemName: "arrow.uturn.backward") }
                .disabled(!viewModel.canUndo)
                .buttonStyle(ToolbarButton())
            
            Button(action: { viewModel.redo() }) { Image(systemName: "arrow.uturn.forward") }
                .disabled(!viewModel.canRedo)
                .buttonStyle(ToolbarButton())
        }
    }
    
    func addTrackButton(rowHeight: CGFloat) -> some View {
        Button(action: { viewModel.executeAddTrack() }) {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("Add Track")
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding(.horizontal, 12)
            .frame(width: leftColumnWidth, height: rowHeight)
            .background(Color(white: 0.15))
            .foregroundColor(.cyan)
            .cornerRadius(6)
        }
    }
}
