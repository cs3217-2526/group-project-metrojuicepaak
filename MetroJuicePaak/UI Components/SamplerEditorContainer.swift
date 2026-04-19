//
//  SamplerEditorContainer.swift
//  MetroJuicePaak
//
//  Created by Noah Ang Shi Hern on 19/4/26.
//

import SwiftUI

struct SamplerEditorContainer: View {

    @State private var editorViewModel: SamplerEditorViewModel?
    @State private var effectsViewModel: EffectChainEditorViewModel?

    init(orchestrator: SamplerViewModel, sampleID: ObjectIdentifier) {
        _editorViewModel = State(
            initialValue: orchestrator.getEditorViewModel(for: sampleID)
        )
        _effectsViewModel = State(
            initialValue: orchestrator.getEffectsEditorViewModel(for: sampleID)
        )
    }

    var body: some View {
        if let editorVM = editorViewModel,
           let effectsVM = effectsViewModel {
            SamplerEditorView(
                editorViewModel: editorVM,
                effectsViewModel: effectsVM
            )
        } else {
            Text("Error loading sample editor.")
                .foregroundColor(.red)
        }
    }
}
