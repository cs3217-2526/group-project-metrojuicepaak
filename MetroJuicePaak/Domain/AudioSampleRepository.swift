//
//  AudioSampleRepository.swift
//  MetroJuicePaak
//
//  Created by Noah Ang Shi Hern on 4/4/26.
//

import Foundation
import Observation

// MARK: - Segregated Protocols

/// A read-only view of the sample repository.
///
/// Consumers that only need to look up samples for playback or display — the
/// sampler, the step sequencer, the repository browser — depend on this
/// protocol rather than the concrete repository, so they cannot accidentally
/// mutate the pool or rename samples.
protocol ReadableAudioSampleRepository {
    var allSamples: [PlayableAudioSample & NamedAudioSample] { get }
    func getPlayableSample(for id: ObjectIdentifier) -> PlayableAudioSample?
    func getNamedSample(for id: ObjectIdentifier) -> (PlayableAudioSample & NamedAudioSample)?
}

/// Errors that may occur when modifying the contents of the repository.
enum WritableAudioSampleRepositoryError: Error, LocalizedError {
    /// A sample with the requested name already exists in the pool.
    case nameConflict(name: String)
    /// The sample identified for mutation is not present in the pool.
    case sampleNotFound

    var errorDescription: String? {
        switch self {
        case .nameConflict(let name):
            return "A sample named \(name) already exists. Please pick another name!"
        case .sampleNotFound:
            return "The requested sample no longer exists in the repository."
        }
    }
}

/// A write-access view of the sample repository.
///
/// Used by recording and import flows to add new samples, and by UI surfaces
/// (waveform editor, repository browser) to rename or remove samples.
/// Naming uniqueness is enforced here because uniqueness is a property of the
/// collection, which only the repository has visibility into.
///
/// New samples are always inserted with an auto-generated "Untitled N" name.
/// User-supplied naming happens *after* insertion via ``renameSample(id:to:)``,
/// which keeps uniqueness validation centralized at a single mutation point.
protocol WritableAudioSampleRepository {
    func addSample(url: URL) -> ObjectIdentifier
    func removeSample(id: ObjectIdentifier)
    func renameSample(id: ObjectIdentifier, to newName: String) throws(WritableAudioSampleRepositoryError)
}

/// An edit-access view of the sample repository.
///
/// Hands out `EditableAudioSample` views for trim manipulation. Consumed
/// primarily by the waveform editor.
protocol EditableAudioSampleRepository {
    func getEditableSample(for id: ObjectIdentifier) -> EditableAudioSample?
}

/// An effect-chain access view of the sample repository.
///
/// Hands out `EffectableAudioSample` views for managing per-sample DSP effect
/// chains. Consumed by the effect rack UI.
protocol EffectableAudioSampleRepository {
    func getEffectableSample(for id: ObjectIdentifier) -> EffectableAudioSample?
}

/// A waveform-rendering access view of the sample repository.
///
/// Hands out `WaveformSource` views for thumbnail and waveform editor
/// rendering. Consumed by any UI surface that displays a sample's visual
/// shape — sampler pads, sequencer steps, the waveform editor itself.
protocol WaveformSourceAudioSampleRepository {
    func getWaveformSource(for id: ObjectIdentifier) -> WaveformSource?
}

// MARK: - Concrete AudioSampleRepository Implementation

/// The canonical owner of every `AudioSample` in the current session.
///
/// `AudioSampleRepository` is the single source of truth for the project pool.
/// It is a reference type because every ViewModel that interacts with samples
/// must share the same instance — handing out narrow protocol views of samples
/// (`PlayableAudioSample`, `EditableAudioSample`, etc.) only works if all those
/// views point at the same underlying object.
///
/// The repository deliberately conforms to several segregated protocols rather
/// than exposing all of its capabilities through a single fat interface.
/// Consumers depend on the narrowest repository protocol that satisfies their
/// needs (interface segregation), which mirrors the same segregation applied
/// to `AudioSample` itself one layer below.
///
/// Concerns owned here:
/// - Sample lifecycle (add, remove)
/// - Naming policy (auto-generated "Untitled N" defaults, uniqueness enforcement)
/// - Issuing narrow protocol views to consumers
///
/// Concerns explicitly *not* owned here:
/// - UI state, waveform rendering, audio engine integration — those live in
///   higher-level ViewModels and the audio service layer.
/// - File-on-disk lifecycle. Removing a sample does not delete the underlying
///   recording; cleanup is a separate, batched operation that scans for
///   unreferenced files.
@Observable
final class AudioSampleRepository: ReadableAudioSampleRepository,
                                    WritableAudioSampleRepository,
                                    EditableAudioSampleRepository,
                                    EffectableAudioSampleRepository,
                                    WaveformSourceAudioSampleRepository {

    // MARK: - Storage

    /// The master pool of every `AudioSample` the user has recorded this session.
    ///
    /// Keyed by `ObjectIdentifier` so that lookup is independent of name —
    /// renaming a sample never invalidates references held elsewhere.
    private var samples: [ObjectIdentifier: AudioSample] = [:]

    // MARK: - ReadableAudioSampleRepository

    var allSamples: [PlayableAudioSample & NamedAudioSample] {
        Array(samples.values)
    }

    func getPlayableSample(for id: ObjectIdentifier) -> PlayableAudioSample? {
        samples[id]
    }

    func getNamedSample(for id: ObjectIdentifier) -> (PlayableAudioSample & NamedAudioSample)? {
        samples[id]
    }

    // MARK: - WritableAudioSampleRepository

    /// Adds a new sample to the pool with an auto-generated "Untitled N" name.
    ///
    /// This is the sole entry point for sample creation. The repository is the
    /// only component in the codebase that calls `AudioSample.init`, which
    /// guarantees that every sample in existence has gone through the naming
    /// pipeline. Callers that want a user-supplied name should call
    /// ``renameSample(id:to:)`` immediately after `addSample` — splitting the
    /// two operations keeps uniqueness validation at a single site rather
    /// than branching inside this method.
    ///
    /// `addSample` does not throw because auto-generated names are guaranteed
    /// unique by ``calculateNextDefaultName()``.
    ///
    /// - Parameter url: The on-disk location of the recorded or imported audio file.
    /// - Returns: The `ObjectIdentifier` of the newly added sample. Callers
    ///            use this ID to obtain narrow views of the sample via the
    ///            other repository accessors.
    @discardableResult
    func addSample(url: URL) -> ObjectIdentifier {
        let sample = AudioSample(url: url, name: calculateNextDefaultName())
        let id = ObjectIdentifier(sample)
        samples[id] = sample
        return id
    }

    /// Removes a sample from the pool.
    ///
    /// Removing an ID that is not in the pool is a safe no-op — deletion is
    /// idempotent. Callers holding stale references to the removed sample
    /// will continue to function (the underlying object remains alive as long
    /// as some reference exists), but the sample is no longer reachable
    /// through the repository.
    func removeSample(id: ObjectIdentifier) {
        samples.removeValue(forKey: id)
    }

    /// Renames a sample after verifying that the new name is not already in use.
    ///
    /// Renaming is a *repository operation* rather than a sample operation
    /// because uniqueness is a collection-level invariant. Routing all renames
    /// through this method guarantees that no path exists by which the pool
    /// can end up with two samples sharing a name.
    ///
    /// - Throws: ``WritableAudioSampleRepositoryError/sampleNotFound`` if the
    ///           ID does not correspond to a sample in the pool, or
    ///           ``WritableAudioSampleRepositoryError/nameConflict(name:)`` if
    ///           the new name is already in use by another sample.
    func renameSample(id: ObjectIdentifier, to newName: String) throws(WritableAudioSampleRepositoryError) {
        guard let sample = samples[id] else {
            throw .sampleNotFound
        }
        // Renaming to the current name is a no-op, not a conflict.
        guard sample.name != newName else { return }
        guard !isNameInUse(newName) else {
            throw .nameConflict(name: newName)
        }
        sample.name = newName
    }

    // MARK: - EditableAudioSampleRepository

    func getEditableSample(for id: ObjectIdentifier) -> EditableAudioSample? {
        samples[id]
    }

    // MARK: - EffectableAudioSampleRepository

    func getEffectableSample(for id: ObjectIdentifier) -> EffectableAudioSample? {
        samples[id]
    }

    // MARK: - WaveformSourceAudioSampleRepository
    
    func getWaveformSource(for id: ObjectIdentifier) -> WaveformSource? {
        samples[id]
    }

    // MARK: - Naming Policy

    private static let defaultNamePrefix = "Untitled"

    /// Returns whether any sample in the pool currently has the given name.
    private func isNameInUse(_ name: String) -> Bool {
        samples.values.contains { $0.name == name }
    }

    /// Scans the pool and returns the next available "Untitled N" name.
    ///
    /// Works in two steps:
    ///   1. Collect every number already in use by iterating the pool and
    ///      parsing the numeric suffix from names matching "Untitled N".
    ///      Anything that doesn't match (custom names, partial matches) is
    ///      ignored via `compactMap` returning `nil`.
    ///   2. Start at 1 and increment until a number not in that set is found.
    ///      This fills gaps — if "Untitled 1" and "Untitled 3" exist, it
    ///      returns "Untitled 2" rather than "Untitled 4".
    private func calculateNextDefaultName() -> String {
        let usedNumbers = Set(
            samples.values.compactMap { sample -> Int? in
                guard sample.name.hasPrefix(Self.defaultNamePrefix) else { return nil }
                let suffix = sample.name
                    .dropFirst(Self.defaultNamePrefix.count)
                    .trimmingCharacters(in: .whitespaces)
                return Int(suffix)
            }
        )

        var candidate = 1
        while usedNumbers.contains(candidate) {
            candidate += 1
        }
        return "\(Self.defaultNamePrefix) \(candidate)"
    }
}
