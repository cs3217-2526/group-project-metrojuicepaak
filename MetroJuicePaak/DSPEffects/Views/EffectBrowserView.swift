//
//  EffectBrowserView.swift
//  MetroJuicePaak
//
//  Created by Noah Ang Shi Hern on 18/4/26.
//

import SwiftUI

struct EffectBrowserView: View {

    let viewModel: EffectChainEditorViewModel

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(EffectCategory.allCases, id: \.self) { category in
                    let effects = viewModel.availableEffectsByCategory[category] ?? []
                    if !effects.isEmpty {
                        Section(category.rawValue.capitalized) {
                            ForEach(effects, id: \.identifier) { metadata in
                                Button {
                                    Task {
                                        try? await viewModel.addEffect(
                                            identifier: metadata.identifier
                                        )
                                        dismiss()
                                    }
                                } label: {
                                    VStack(alignment: .leading) {
                                        Text(metadata.displayName)
                                            .font(.body)
                                        Text("\(metadata.parameterDescriptors.count) parameters")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Effect")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
