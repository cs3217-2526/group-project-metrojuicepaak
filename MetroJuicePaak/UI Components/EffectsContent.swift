//
//  EffectsContent.swift
//  MetroJuicePaak
//
//  Created by Noah Ang Shi Hern on 19/4/26.
//

import SwiftUI

// MARK: - Effects Content

/// Minimal effects view: shows current effect count and an "Add Effect" button.
/// Tapping the button presents `EffectBrowserView` as a sheet.
struct EffectsContent: View {

    let viewModel: EffectChainEditorViewModel

    @State private var showingBrowser = false
    @State private var expandedInstanceId: UUID?

    var body: some View {
        VStack(spacing: 12) {

            // MARK: - Header
            HStack {
                Text("Effects")
                    .font(.headline)
                Spacer()
                Text("\(viewModel.chain.count) / \(EffectLimits.maxEffectsPerChain)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            // MARK: - Play Button
            Button {
                Task { await viewModel.togglePreview() }
            } label: {
                Image(systemName: viewModel.isPlayingPreview
                      ? "stop.circle.fill" : "play.circle.fill")
                    .font(.system(size: 44))
                    .foregroundColor(viewModel.isPlayingPreview ? .red : .cyan)
                    .contentTransition(.symbolEffect(.replace))
            }
            .padding(.vertical, 4)

            // MARK: - Effect List
            if viewModel.chain.isEmpty {
                Text("No effects yet")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 80)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(viewModel.chain) { instance in
                            ExpandableEffectRow(
                                instance: instance,
                                metadata: viewModel.metadata(
                                    for: instance.effectIdentifier
                                ),
                                isExpanded: expandedInstanceId == instance.id,
                                onTap: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        expandedInstanceId =
                                            expandedInstanceId == instance.id
                                            ? nil
                                            : instance.id
                                    }
                                },
                                onRemove: {
                                    Task {
                                        try? await viewModel.removeEffect(
                                            instanceId: instance.id
                                        )
                                    }
                                },
                                viewModel: viewModel
                            )
                        }
                    }
                    .padding(.horizontal)
                }
            }

            // MARK: - Add Effect Button
            if viewModel.chain.count < EffectLimits.maxEffectsPerChain {
                Button {
                    showingBrowser = true
                } label: {
                    Label("Add Effect", systemImage: "plus.circle")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
                .padding(.horizontal)
            } else {
                Text("Maximum effects reached")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .sheet(isPresented: $showingBrowser) {
            EffectBrowserView(viewModel: viewModel)
        }
    }
}

// MARK: - Helper Views

struct ExpandableEffectRow: View {

    let instance: EffectInstanceDescriptor
    let metadata: EffectMetadata?
    let isExpanded: Bool
    let onTap: () -> Void
    let onRemove: () -> Void
    let viewModel: EffectChainEditorViewModel

    var body: some View {
        VStack(spacing: 0) {

            // MARK: - Header Row (tappable)
            HStack {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(metadata?.displayName ?? instance.effectIdentifier)
                    .font(.body)

                Spacer()

                Button(role: .destructive, action: onRemove) {
                    Image(systemName: "xmark.circle")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .contentShape(Rectangle())   // makes the whole row tappable, not just text
            .onTapGesture(perform: onTap)

            // MARK: - Expanded Parameter Panel
            if isExpanded, let metadata = metadata {
                Divider()
                EffectPanelView(
                    effectInstance: instance,
                    metadata: metadata,
                    viewModel: viewModel
                )
                .padding(12)
            }
        }
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct TrimHandle: View {
    var body: some View {
        Rectangle()
            .fill(Color.white)
            .frame(width: 4)
            .overlay(
                Rectangle()
                    .fill(Color.white.opacity(0.01))
                    .frame(width: 30)
            )
    }
}
