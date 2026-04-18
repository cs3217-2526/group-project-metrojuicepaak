import SwiftUI

/// The modal interface for editing audio samples — trim markers and effect chain.
struct WaveformEditorView: View {

    let waveformViewModel: WaveformEditorViewModel
    let effectsViewModel: EffectChainEditorViewModel

    @Binding var editorMode: SampleEditorMode

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {

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
                ForEach(SampleEditorMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            // MARK: - Mode-Specific Content
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

// MARK: - Trim Content

/// The existing waveform trim UI, extracted into its own view so the parent
/// can swap between trim and effects modes.
struct WaveformTrimContent: View {

    let viewModel: WaveformEditorViewModel

    @State private var lastStartRatio: CGFloat = 0.0
    @State private var lastEndRatio: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 20) {
            GeometryReader { geometry in
                let width = geometry.size.width
                let startRatio = CGFloat(viewModel.tempStartRatio)
                let endRatio = CGFloat(viewModel.tempEndRatio)

                ZStack(alignment: .leading) {

                    if let waveform = viewModel.waveformData {
                        SamplerThumbnailView(data: waveform, strokeColor: .cyan)
                    } else {
                        Text("Loading visual...")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }

                    Rectangle()
                        .fill(Color.black.opacity(0.6))
                        .frame(width: startRatio * width)

                    Rectangle()
                        .fill(Color.black.opacity(0.6))
                        .frame(width: (1.0 - endRatio) * width)
                        .offset(x: endRatio * width)

                    TrimHandle()
                        .offset(x: startRatio * width)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    viewModel.stopPreview()
                                    let delta = value.translation.width / width
                                    let proposed = lastStartRatio + delta
                                    let clamped = max(0.0, min(proposed, endRatio - 0.05))
                                    viewModel.tempStartRatio = Double(clamped)
                                }
                                .onEnded { _ in lastStartRatio = startRatio }
                        )

                    TrimHandle()
                        .offset(x: (endRatio * width) - 4)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    viewModel.stopPreview()
                                    let delta = value.translation.width / width
                                    let proposed = lastEndRatio + delta
                                    let clamped = min(1.0, max(proposed, startRatio + 0.05))
                                    viewModel.tempEndRatio = Double(clamped)
                                }
                                .onEnded { _ in lastEndRatio = endRatio }
                        )
                }
                .onAppear {
                    self.lastStartRatio = startRatio
                    self.lastEndRatio = endRatio
                }
                .task {
                    if viewModel.waveformData == nil {
                        await viewModel.generateThumbnail(resolution: Int(width))
                    }
                }
            }
            .frame(height: 150)
            .background(Color.black.opacity(0.8))
            .cornerRadius(8)
            .padding(.horizontal)

            HStack(spacing: 40) {
                Button {
                    Task { await viewModel.togglePreview() }
                } label: {
                    Image(systemName: viewModel.isPlayingPreview
                          ? "stop.circle.fill" : "play.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(viewModel.isPlayingPreview ? .red : .cyan)
                        .contentTransition(.symbolEffect(.replace))
                }
            }
        }
    }
}

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

// MARK: - Memory Container

struct WaveformEditorContainer: View {

    @State private var waveformViewModel: WaveformEditorViewModel?
    @State private var effectsViewModel: EffectChainEditorViewModel?
    @State private var editorMode: SampleEditorMode = .trim

    init(orchestrator: SamplerViewModel, sampleID: ObjectIdentifier) {
        _waveformViewModel = State(
            initialValue: orchestrator.getEditorViewModel(for: sampleID)
        )
        _effectsViewModel = State(
            initialValue: orchestrator.getEffectsEditorViewModel(for: sampleID)
        )
    }

    var body: some View {
        if let waveformVM = waveformViewModel,
           let effectsVM = effectsViewModel {
            WaveformEditorView(
                waveformViewModel: waveformVM,
                effectsViewModel: effectsVM,
                editorMode: $editorMode
            )
        } else {
            Text("Error loading sample editor.")
                .foregroundColor(.red)
        }
    }
}
