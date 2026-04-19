//
//  TrackHeaderView.swift
//  MetroJuicePaak
//
//  Created by Edwin Wong on 27/03/2026.
//

import SwiftUI

struct TrackHeaderView: View {
    var track: SequencerTrack
    let viewModel: StepSequencerViewModel
    
    var body: some View {
        HStack(spacing: 0) {
            deleteTrackButton()
            sampleAssignmentMenu()
        }
        .frame(width: 150)
        .background(Color(white: 0.15))
        .cornerRadius(4)
    }
    
    // MARK: - UI Components
    
    @ViewBuilder
    private func deleteTrackButton() -> some View {
        Button(action: {
            viewModel.executeRemoveTrack(trackId: track.id)
        }) {
            Image(systemName: "xmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Color(white: 0.5))
                .frame(width: 28, height: 44)
        }
    }
    
    @ViewBuilder
    private func sampleAssignmentMenu() -> some View {
        Menu {
            assignSampleSection()
            removeSampleSection()
        } label: {
            menuTriggerLabel()
        }
    }
    
    // MARK: - Helper Functions
    
    @ViewBuilder
    private func assignSampleSection() -> some View {
        Section("Assign Sample to Track") {
            let availableSamples = viewModel.repository.allSamples
            
            if availableSamples.isEmpty {
                Text("No samples loaded")
            } else {
                ForEach(availableSamples, id: \.name) { sample in
                    let sampleID = ObjectIdentifier(sample)
                    let isCurrent = track.sampleID == sampleID
                    
                    Button(action: {
                        viewModel.executeAssignSample(trackId: track.id, sampleID: sampleID)
                    }) {
                        HStack {
                            Text(sample.name)
                            if isCurrent { Image(systemName: "checkmark") }
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func removeSampleSection() -> some View {
        if track.sampleID != nil {
            Divider()
            Button(role: .destructive, action: {
                viewModel.executeRemoveSample(trackId: track.id)
            }) {
                Label("Remove Sample", systemImage: "trash")
            }
        }
    }
    
    @ViewBuilder
    private func menuTriggerLabel() -> some View {
        HStack(spacing: 6) {
            Image(systemName: "speaker.wave.2.fill")
                .font(.system(size: 10))
                .foregroundColor(track.sampleID != nil ? Color(red: 0.0, green: 0.8, blue: 0.9) : Color(white: 0.4))
            
            Text(currentSampleName)
                .font(.caption.bold())
                .foregroundColor(track.sampleID != nil ? .white : Color(white: 0.5))
                .lineLimit(1)
            
            Spacer()
            
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 10))
                .foregroundColor(Color(white: 0.4))
        }
        .padding(.trailing, 8)
        .frame(height: 44)
    }
    
    private var currentSampleName: String {
        guard let sampleID = track.sampleID,
              let namedSample = viewModel.repository.getNamedSample(for: sampleID) else {
            return "Empty Track"
        }
        return namedSample.name
    }
}
