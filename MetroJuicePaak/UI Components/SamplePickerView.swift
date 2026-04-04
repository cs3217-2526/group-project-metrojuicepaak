//
//  SamplePickerView.swift
//  MetroJuicePaak
//
//  Created by Noah Ang Shi Hern on 4/4/26.
//

import SwiftUI

/// A modal sheet listing every recorded sample in the pool.
///
/// Presented by both the Sampler (per-pad load button) and the Step Sequencer
/// (per-track load button). When the user selects a row the `onSelect` callback
/// fires with the shared AudioClipViewModel for that sample, then the sheet
/// dismisses itself.
///
/// Usage:
/// ```swift
/// .sheet(isPresented: $showingPicker) {
///     SamplePickerView(sessionManager: sessionManager) { node in
///         viewModel.assignClipNode(node, toPad: selectedPadIndex)
///     }
/// }
/// ```
struct SamplePickerView: View {
    let sessionManager: AudioSampleRepositoryViewModel
    let onSelect: (AudioClipViewModel) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if sessionManager.allClipNodes.isEmpty {
                    emptyState
                } else {
                    sampleList
                }
            }
            .navigationTitle("Choose Sample")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    // ─────────────────────────────────────────
    // MARK: - Subviews
    // ─────────────────────────────────────────

    private var sampleList: some View {
        List(sessionManager.allClipNodes, id: \.sample.id) { node in
            Button {
                onSelect(node)
                dismiss()
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(node.sample.name)
                            .foregroundStyle(.primary)
                        Text(durationLabel(node.sample.duration))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No Recordings",
            systemImage: "waveform.slash",
            description: Text("Record a sample on a pad first.")
        )
    }

    // ─────────────────────────────────────────
    // MARK: - Helpers
    // ─────────────────────────────────────────

    private func durationLabel(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        let centiseconds = Int((duration.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%d:%02d.%02d", minutes, seconds, centiseconds)
    }
}
