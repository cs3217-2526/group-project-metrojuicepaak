//
//  SampleEditorView.swift
//  MetroJuicePaak
//
//  Created by Noah Ang Shi Hern on 18/4/26.
//

import SwiftUI

struct SampleEditorView: View {

    @Binding var editorMode: SampleEditorMode
    let waveformViewModel: WaveformEditorViewModel
    let effectsViewModel: EffectChainEditorViewModel

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {

            // MARK: - Toolbar
            HStack {
                Button("Cancel") {
                    waveformViewModel.cancelEdits()
                    dismiss()
                }
                .foregroundColor(.red)

                Spacer()
                Text("Edit Sample").font(.headline)
                Spacer()

                Button("Save") {
                    waveformViewModel.saveEdits()
                    dismiss()
                }
                .bold()
            }
            .padding()

            // MARK: - Mode Toggle
            Picker("Editor Mode", selection: $editorMode) {
                ForEach(SampleEditorMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            // MARK: - Content Area
            switch editorMode {
            case .trim:
                WaveformTrimContent(viewModel: waveformViewModel)

            case .effects:
                EffectsContent(viewModel: effectsViewModel)
            }

            Spacer()
        }
    }
}
