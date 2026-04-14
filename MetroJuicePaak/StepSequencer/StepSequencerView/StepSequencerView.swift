////
////  StepSequencerView.swift
////  MetroJuicePaak
////
////  Created by Edwin Wong on 27/03/2026.
////
//
//import SwiftUI
//
//struct StepSequencerView: View {
//    @State private var viewModel: StepSequencerViewModel
//    
//    let leftColumnWidth: CGFloat = 160
//    
//    init(viewModel: StepSequencerViewModel) {
//        self.viewModel = viewModel
//    }
//    
//    var body: some View {
//        VStack(spacing: 0) {
//            // MARK: Top Toolbar
//            HStack {
//                Button(action: { viewModel.togglePlayback() }) {
//                    Image(systemName: viewModel.isPlaying ? "stop.fill" : "play.fill")
//                        .font(.title2)
//                        .foregroundStyle(viewModel.isPlaying ? .red : .green)
//                        .frame(width: 44, height: 44)
//                        .background(Color(white: 0.15))
//                        .cornerRadius(8)
//                }
//                
//                Menu {
//                    ForEach(viewModel.availableLengths, id: \.self) { length in
//                        Button("\(length) Steps") { viewModel.changeSequenceLength(to: length) }
//                    }
//                } label: {
//                    HStack {
//                        Text("\(viewModel.sequencerModel.sequenceLength) Steps")
//                            .fontWeight(.semibold)
//                        Image(systemName: "chevron.up.chevron.down")
//                            .font(.caption)
//                    }
//                    .padding(.horizontal, 12)
//                    .frame(height: 44)
//                    .background(Color(white: 0.15))
//                    .foregroundColor(.white)
//                    .cornerRadius(8)
//                }
//                .padding(.leading, 8)
//                
//                HStack(spacing: 12) {
//                    Button(action: { viewModel.decrementBPM() }) {
//                        Image(systemName: "minus")
//                            .font(.body.weight(.bold))
//                            .foregroundColor(.gray)
//                    }
//                    
//                    Text("\(Int(viewModel.bpm)) BPM")
//                        .font(.system(.body, design: .monospaced))
//                        .fontWeight(.bold)
//                        .foregroundColor(.cyan)
//                        .frame(width: 80)
//                    
//                    Button(action: { viewModel.incrementBPM() }) {
//                        Image(systemName: "plus")
//                            .font(.body.weight(.bold))
//                            .foregroundColor(.gray)
//                    }
//                }
//                .padding(.horizontal, 12)
//                .frame(height: 44)
//                .background(Color(white: 0.15))
//                .cornerRadius(8)
//                .padding(.leading, 8)
//                
//                Spacer()
//                
//                Button(action: { viewModel.undo() }) { Image(systemName: "arrow.uturn.backward") }
//                    .disabled(!viewModel.canUndo)
//                    .buttonStyle(ToolbarButton())
//                
//                Button(action: { viewModel.redo() }) { Image(systemName: "arrow.uturn.forward") }
//                    .disabled(!viewModel.canRedo)
//                    .buttonStyle(ToolbarButton())
//            }
//            .padding()
//            .background(Color(white: 0.1))
//            
//            // MARK: Sequencer Area
//            GeometryReader { gridGeometry in
//                let maxRows: CGFloat = 16
//                let verticalSpacing: CGFloat = 4
//                let totalVerticalSpacing = (maxRows - 1) * verticalSpacing
//                let rowHeight = max(10, (gridGeometry.size.height - totalVerticalSpacing) / maxRows)
//                
//                let horizontalSpacing: CGFloat = 2.0
//                let totalHorizontalSpacing = CGFloat(viewModel.sequencerModel.sequenceLength - 1) * horizontalSpacing
//                let availableGridWidth = gridGeometry.size.width - leftColumnWidth - 16
//                let stepWidth = max(1, (availableGridWidth - totalHorizontalSpacing) / CGFloat(viewModel.sequencerModel.sequenceLength))
//                
//                HStack(alignment: .top, spacing: 4) {
//                    // LEFT COLUMN: Track Headers
//                    VStack(spacing: verticalSpacing) {
//                        ForEach(viewModel.sequencerModel.tracks) { track in
//                            if let trackIndex = viewModel.sequencerModel.tracks.firstIndex(where: { $0.id == track.id }) {
//                                TrackHeaderView(trackIndex: trackIndex, viewModel: viewModel, rowHeight: rowHeight)
//                            }
//                        }
//                        
//                        if viewModel.canAddMoreTracks {
//                            Menu {
//                                ForEach(viewModel.availablePadsToAdd) { pad in
//                                    let padNum = viewModel.padNumber(for: pad.id)
//                                    Button {
//                                        viewModel.addTrack(for: pad.id)
//                                    } label: {
//                                        HStack {
//                                            Text("Pad \(padNum)")
//                                            if pad.isSampleLoaded { Image(systemName: "waveform") }
//                                        }
//                                    }
//                                }
//                            } label: {
//                                HStack {
//                                    Image(systemName: "plus.circle.fill")
//                                    Text("Add Sample")
//                                        .fontWeight(.semibold)
//                                    Spacer()
//                                }
//                                .padding(.horizontal, 12)
//                                .frame(width: leftColumnWidth, height: rowHeight)
//                                .background(Color(white: 0.15))
//                                .foregroundColor(.cyan)
//                                .cornerRadius(6)
//                            }
//                        }
//                        
//                        Spacer(minLength: 0)
//                    }
//                    .frame(width: leftColumnWidth)
//                    
//                    // RIGHT COLUMN: Step Grid
//                    VStack(spacing: verticalSpacing) {
//                        ForEach(viewModel.sequencerModel.tracks) { track in
//                            if let trackIndex = viewModel.sequencerModel.tracks.firstIndex(where: { $0.id == track.id }) {
//                                HStack(spacing: horizontalSpacing) {
//                                    ForEach(0..<viewModel.sequencerModel.sequenceLength, id: \.self) { stepIndex in
//                                        StepButton(
//                                            isActive: viewModel.isStepActive(trackIndex: trackIndex, stepIndex: stepIndex),
//                                            isCurrentStep: viewModel.isPlaying && viewModel.currentStep == stepIndex,
//                                            width: stepWidth,
//                                            height: rowHeight
//                                        ) {
//                                            viewModel.toggleStep(trackIndex: trackIndex, stepIndex: stepIndex)
//                                        }
//                                    }
//                                }
//                            }
//                        }
//                        Spacer(minLength: 0)
//                    }
//                }
//                .padding(.horizontal, 8)
//                .padding(.top, 8)
//            }
//            .background(Color.black)
//        }
//        .navigationBarTitleDisplayMode(.inline)
//        .ignoresSafeArea(.keyboard, edges: .bottom)
//    }
//}
