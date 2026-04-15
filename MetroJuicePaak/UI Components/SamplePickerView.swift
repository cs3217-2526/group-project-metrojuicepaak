//  SamplePickerView.swift
//  MetroJuicePaak
//
//  Created by Noah Ang Shi Hern on 13/4/26.
//

import SwiftUI

/// A reusable sample-selection UI that presents every sample in the repository
/// as a tappable list and reports the user's choice as an `ObjectIdentifier`.
///
/// `SamplePickerView` is deliberately *capability-agnostic*: it reads only the
/// display name of each sample and reports selections as opaque identifiers,
/// with no awareness of what the caller intends to do with the chosen sample.
/// This keeps the picker's dependency surface minimal (just
/// ``ReadableAudioSampleRepository``) and lets the same view be reused by
/// every consumer that needs to pick a sample — sampler pads, sequencer
/// steps, the waveform editor, the effect rack — regardless of which narrow
/// protocol view they will subsequently request from the repository.
///
/// ### How callers use the result
///
/// The picker emits an `ObjectIdentifier` via the ``onSelect`` closure. The
/// consumer then calls its own repository accessor to obtain the narrow
/// protocol view matching its needs. For example, a sampler that wants to
/// assign the selection to a pad looks up a ``PlayableAudioSample``; a
/// waveform editor host looks up an ``EditableAudioSample`` and a
/// ``WaveformSource``. The picker never produces these narrow views itself.
///
/// This separation is intentional: the repository type tells the picker
/// *what it can read* (names, for display), while the closure tells it
/// *what to do with the selection* (which is consumer-specific and cannot
/// be inferred from the repository type alone). Multiple consumers holding
/// the same `ReadableAudioSampleRepository` protocol may want to do entirely
/// different things when a sample is picked — assign, edit, inspect, delete —
/// and the closure is how each consumer expresses its own intent.
///
/// ### Usage — assigning a sample to a sampler pad
///
/// ```swift
/// struct PadAssignmentView: View {
///     let samplerVM: SamplerViewModel
///     let repo: ReadableAudioSampleRepository
///     @State private var showingPicker = false
///
///     var body: some View {
///         Button("Assign Sample") { showingPicker = true }
///             .sheet(isPresented: $showingPicker) {
///                 SamplePickerView(repository: repo) { id in
///                     samplerVM.assignCurrentPad(sampleId: id)
///                     showingPicker = false
///                 }
///             }
///     }
/// }
/// ```
///
/// The sampler view model internally calls `repo.getPlayableSample(for: id)`
/// to obtain the narrow view it needs — the picker is not involved in that
/// lookup.
///
/// ### Usage — opening a sample in the waveform editor
///
/// ```swift
/// struct EditorHostView: View {
///     let repo: ReadableAudioSampleRepository
///              & EditableAudioSampleRepository
///              & WaveformSourceAudioSampleRepository
///     @State private var editingSampleId: ObjectIdentifier?
///     @State private var showingPicker = false
///
///     var body: some View {
///         Button("Pick a sample to edit") { showingPicker = true }
///             .sheet(isPresented: $showingPicker) {
///                 SamplePickerView(repository: repo) { id in
///                     editingSampleId = id
///                     showingPicker = false
///                 }
///             }
///             .sheet(item: $editingSampleId) { id in
///                 WaveformEditorView(sampleId: id, repository: repo)
///             }
///     }
/// }
/// ```
///
/// Note that the host view holds `EditableAudioSampleRepository` and
/// `WaveformSourceAudioSampleRepository` because *the editor* needs them —
/// the picker itself only requires `ReadableAudioSampleRepository`.
///
/// - Important: `NamedAudioSample` (and its composition parents) must be
///              `AnyObject`-constrained for `ObjectIdentifier` construction
///              to yield the same identity the repository uses as its
///              dictionary key. Without that constraint, IDs emitted by the
///              picker may fail to match the repository's keys at lookup
///              time, causing subsequent accessor calls to return `nil`.
struct SamplePickerView: View {
    
    /// The repository whose samples will be presented for selection.
    ///
    /// Only the read-only protocol is required. The picker calls
    /// ``ReadableAudioSampleRepository/allSamples`` to enumerate the pool and
    /// reads each sample's display name for the row label. It never mutates
    /// the repository, never requests edit or effect capabilities, and never
    /// holds a reference to any concrete `AudioSample`.
    let repository: ReadableAudioSampleRepository
    
    /// Invoked when the user taps a row, with the `ObjectIdentifier` of the
    /// chosen sample.
    ///
    /// The consumer is responsible for turning this identifier into whatever
    /// narrow protocol view it needs (by calling the appropriate repository
    /// accessor) and for any side effects — dismissing the picker,
    /// navigating to the next screen, updating view model state, and so on.
    /// The picker performs no action of its own beyond invoking this
    /// closure.
    let onSelect: (ObjectIdentifier) -> Void
    
    var body: some View {
        List {
            ForEach(
                repository.allSamples.sorted { $0.name < $1.name },
                id: \.name
            ) { sample in
                Button {
                    onSelect(ObjectIdentifier(sample))
                } label: {
                    Text(sample.name)
                }
            }
        }
    }
}
