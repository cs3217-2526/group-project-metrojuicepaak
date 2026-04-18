//
//  SamplerEditorView.swift
//  MetroJuicePaak
//
//  Created by Noah Ang Shi Hern on 18/4/26.
//

import SwiftUI

/// The sample editor modal — hosts both the trim and effects modes.
/// The mode toggle is local UI state, not externally observable.
struct SamplerEditorView: View {

    let editorViewModel: SamplerEditorViewModel
    let effectsViewModel: EffectChainEditorViewModel

    @State private var editorMode: SampleEditorMode = .trim
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {

            // MARK: - Toolbar
            HStack {
                Button("Cancel") {
                    editorViewModel.cancelEdits()
                    dismiss()
                }
                .foregroundColor(.red)

                Spacer()
                Text("Edit Sample").font(.headline)
                Spacer()

                Button("Save") {
                    editorViewModel.saveEdits()
                    dismiss()
                }
                .bold()
            }
            .padding()

            // MARK: - Mode Toggle
            Picker("Editor Mode", selection: $editorMode) {
                ForEach(SampleEditorMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            // MARK: - Content Area
            switch editorMode {
            case .trim:
                WaveformTrimContent(viewModel: editorViewModel)
            case .effects:
                EffectsContent(viewModel: effectsViewModel)
            }

            Spacer()
        }
    }
}

// MARK: - Mode Enum

/// Local UI state for which editor mode is active. Not externally observed
/// because no caller needs to read or set the mode from outside the modal.
enum SampleEditorMode: String, CaseIterable, Identifiable {
    case trim = "Trim"
    case effects = "Effects"

    var id: String { rawValue }
}
