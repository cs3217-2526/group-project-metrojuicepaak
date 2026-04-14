//
//  AudioSample.swift
//  MetroJuicePaak
//
//  Created by Noah Ang Shi Hern on 10/4/26.
//

import Foundation


// MARK: - Supporting Types

/// A serializable description of a DSP effect to be applied to an audio sample.
///
/// `EffectDescriptor` lives in the domain layer and is intentionally decoupled
/// from any specific DSP framework (AVFoundation, AudioUnit, etc.). The audio
/// engine is responsible for translating descriptors into concrete effect nodes
/// at playback time.
struct EffectDescriptor {
    //toBeImplementedLater
    var yourMother: Int
}


// MARK: - Segregated Protocols

/// A view of an audio sample exposing its human-readable display name.
///
/// Kept separate from ``PlayableAudioSample`` so that the audio engine — which
/// identifies voices by `ObjectIdentifier` and has no use for display labels —
/// cannot see or depend on naming. UI consumers that need both playback
/// information and a label compose the two: `PlayableAudioSample & NamedAudioSample`.
///
/// - Note: Names are not unique and not stable identifiers. Use
///         `ObjectIdentifier` for identity.
protocol NamedAudioSample: AnyObject {
    var name: String { get }
}

/// A read-only view of an audio sample suitable for playback.
///
/// Systems that only need to *play* a sample — such as the sampler engine
/// and the step sequencer — should depend on this protocol rather than the
/// concrete `AudioSample` type. This guarantees at compile time that the
/// playback path cannot mutate trim markers, effects, or other editable state.
protocol PlayableAudioSample: AnyObject {
    /// The on-disk location of the audio file to play.
    var url: URL { get }
    
    /// Linear playback gain.
    var volume: Double { get }
    
    /// Stereo pan position in the range `[0, 1]`.
    var pan: Double { get }
    
    /// The normalized start of the region to play.
    var startTimeRatio: Double { get }
    
    /// The normalized end of the region to play.
    var endTimeRatio: Double { get }
}

/// A mutable view of an audio sample's mixer-level parameters.
///
/// Used by mixer UIs that need to adjust volume and pan without exposing
/// trim, effect, or playback concerns.
protocol MixableAudioSample {
    var url: URL { get }
    var volume: Double { get set }
    var pan: Double { get set }
}

/// Errors that may occur when editing the trim markers of an audio sample.
enum TimeRatioEditError: Error, LocalizedError {
    /// The supplied ratio falls outside the valid `[0, 1]` range.
    case invalidTimeRatio(ratio: Double)
    
    /// The proposed start time is not strictly less than the end time.
    case startTimeAfterEndTime(startTime: Double, endTime: Double)

    var errorDescription: String? {
        switch self {
        case .invalidTimeRatio(let ratio):
            return "Time ratio \(ratio) must be between 0.0 and 1.0"
        case .startTimeAfterEndTime(let start, let end):
            return "Start time \(start) must be before end time \(end)"
        }
    }
}

/// A mutable view of an audio sample's trim markers.
///
/// The waveform editor is the primary consumer of this protocol. Mutation
/// goes through the validating ``setStartTimeRatio(_:)`` and
/// ``setEndTimeRatio(_:)`` methods rather than direct property assignment,
/// so that invariants (`0 ≤ start < end ≤ 1`) are guaranteed at the
/// boundary between UI input and domain state.
///
/// Constrained to `AnyObject` because edits must be visible to all other
/// holders of the same sample instance — value semantics would defeat the
/// shared-state model.
protocol EditableAudioSample: AnyObject {
    var startTimeRatio: Double { get set }
    var endTimeRatio: Double { get set }
    
    /// Sets the start of the playable region after validating the new value.
    ///
    /// - Parameter ratio: The new normalized start position.
    /// - Throws: ``TimeRatioEditError/invalidTimeRatio(ratio:)`` if the value
    ///           is outside `[0, 1]`, or
    ///           ``TimeRatioEditError/startTimeAfterEndTime(startTime:endTime:)``
    ///           if the new value is not strictly less than the current end.
    func setStartTimeRatio(_ ratio: Double) throws(TimeRatioEditError)
    
    /// Sets the end of the playable region after validating the new value.
    ///
    /// - Parameter ratio: The new normalized end position.
    /// - Throws: ``TimeRatioEditError/invalidTimeRatio(ratio:)`` if the value
    ///           is outside `[0, 1]`, or
    ///           ``TimeRatioEditError/startTimeAfterEndTime(startTime:endTime:)``
    ///           if the new value is not strictly greater than the current start.
    func setEndTimeRatio(_ ratio: Double) throws(TimeRatioEditError)
}

extension EditableAudioSample {
    
    func setStartTimeRatio(_ ratio: Double) throws(TimeRatioEditError) {
        guard ratio >= 0.0 && ratio <= 1.0 else {
            throw TimeRatioEditError.invalidTimeRatio(ratio: ratio)
        }
        guard ratio < endTimeRatio else {
            throw TimeRatioEditError.startTimeAfterEndTime(startTime: ratio, endTime: endTimeRatio)
        }
        startTimeRatio = ratio
    }
    
    func setEndTimeRatio(_ ratio: Double) throws(TimeRatioEditError) {
        guard ratio >= 0.0 && ratio <= 1.0 else {
            throw TimeRatioEditError.invalidTimeRatio(ratio: ratio)
        }
        guard ratio > startTimeRatio else {
            throw TimeRatioEditError.startTimeAfterEndTime(startTime: startTimeRatio, endTime: ratio)
        }
        endTimeRatio = ratio
    }
}

/// Errors that may occur when manipulating the DSP effect chain of a sample.
enum DSPEffectsError: Error, LocalizedError {
    case tooManyEffects

    var errorDescription: String? {
        switch self {
        case .tooManyEffects:
            return "A maximum of 4 effects is allowed per sample, please remove one before adding more."
        }
    }
}

/// A mutable view of an audio sample's DSP effect chain.
///
/// The effect chain is hard-capped at 4 entries to bound real-time CPU cost
/// and to keep the per-voice processing graph predictable. The cap is
/// enforced at the domain layer (here) rather than at the engine, so that
/// invalid states cannot reach the audio thread in the first place.
protocol EffectableAudioSample: AnyObject {
    var effectDescriptorChain: [EffectDescriptor] { get set }
    
    /// Appends an effect descriptor to the chain.
    ///
    /// - Parameter descriptor: The effect to add.
    /// - Throws: ``DSPEffectsError/tooManyEffects`` if the chain already
    ///           contains 4 effects.
    func addEffect(_ descriptor: EffectDescriptor) throws(DSPEffectsError)
}

extension EffectableAudioSample {
    func addEffect(_ descriptor: EffectDescriptor) throws(DSPEffectsError) {
        guard effectDescriptorChain.count < 4 else {
            throw DSPEffectsError.tooManyEffects
        }
        effectDescriptorChain.append(descriptor)
    }
}

/// A read-only view of an audio sample sufficient for waveform/thumbnail rendering.
///
/// The waveform generator opens the file at ``url`` directly and reads any
/// further metadata it needs (sample rate, channel count, frame length) from
/// `AVAudioFile` at the moment of use. This keeps file-format details out of
/// the domain layer.
///
/// Because the trim markers are part of this protocol, any view that observes
/// a `WaveformSource` will automatically re-render when the user adjusts the
/// trim — provided the underlying type opts in to observation (e.g. via
/// `@Observable`).
protocol WaveformSource {
    var url: URL { get }
    var startTimeRatio: Double { get }
    var endTimeRatio: Double { get }
}

// MARK: - Concrete AudioSample Implementation

/// The core domain model representing a single audio sample in the GrooveBox.
///
/// `AudioSample` is a reference type so that edits made through one protocol
/// view (e.g. `EditableAudioSample`) are immediately visible through every
/// other view (e.g. `WaveformSource`, `PlayableAudioSample`) that holds the
/// same instance. This allows multiple ViewModels to share a single source of
/// truth without explicit synchronization.
///
/// The class deliberately conforms to several narrow protocols rather than
/// exposing all of its capabilities directly. Consumers should depend on the
/// narrowest protocol that satisfies their needs (interface segregation),
/// which prevents accidental misuse — e.g. a playback system cannot mutate
/// trim markers because it only sees `PlayableAudioSample`.
///
/// - Note: File metadata such as sample rate and channel count is intentionally
///         *not* stored here. Such information is read directly from
///         `AVAudioFile` at the moment it is needed inside the audio engine.

@Observable
class AudioSample: NamedAudioSample, PlayableAudioSample, EditableAudioSample, EffectableAudioSample, WaveformSource {
    /// The on-disk location of the audio file backing this sample.
    let url: URL
    
    /// A human-readable label for this sample, shown in the UI.
    ///
    /// Names are intended to be unique across the repository so that users can
    /// distinguish samples at a glance — uniqueness is enforced by
    /// `AudioSampleRepository`, which also owns the naming policy for fresh
    /// recordings (e.g. assigning "Untitled 1", "Untitled 2", ...). `AudioSample`
    /// itself simply stores whichever name it was constructed with.
    ///
    /// Despite being unique, `name` is **not** used as an identifier inside the
    /// audio engine. The engine keys voices by `ObjectIdentifier(sample)`, which
    /// is stable for the lifetime of the instance and independent of any
    /// user-visible label that may later be renamed. Display naming and runtime
    /// identity are deliberately kept as separate concerns.
    ///
    /// Exposed to UI consumers via ``NamedAudioSample`` so that systems which
    /// only need to play or process audio cannot accidentally couple to
    /// display metadata.
    var name: String
    
    /// Linear playback gain. `1.0` represents unity gain.
    var volume: Double
    
    /// Stereo pan position in the range `[0, 1]`, where `0.5` is center.
    var pan: Double
    
    /// The normalized start of the playable region, in the range `[0, 1]`.
    ///
    /// Stored as a ratio rather than an absolute time so that the value
    /// remains meaningful regardless of the file's actual duration, and so
    /// that the audio engine can resolve it to a frame position at playback
    /// time using the file's true length.
    var startTimeRatio: Double
    
    /// The normalized end of the playable region, in the range `[0, 1]`.
    ///
    /// See ``startTimeRatio`` for the rationale behind ratio-based storage.
    var endTimeRatio: Double
    
    /// The ordered chain of DSP effects applied to this sample during playback.
    ///
    /// The chain is capped at 4 effects, enforced by ``EffectableAudioSample/addEffect(_:)``.
    var effectDescriptorChain: [EffectDescriptor]
    
    /// Creates a new audio sample.
    ///
    /// - Parameters:
    ///   - url: The on-disk location of the audio file.
    ///   - name: A human-readable name for display in the UI.
    ///   - startTimeRatio: The normalized start of the playable region.
    ///   - endTimeRatio: The normalized end of the playable region.
    ///   - effectDescriptorChain: Initial chain of DSP effects. Defaults to empty.
    ///   - volume: Initial linear gain. Defaults to unity (`1.0`).
    ///   - pan: Initial stereo pan. Defaults to center (`0.5`).
    init(url: URL, name: String, startTimeRatio: Double = 0.0, endTimeRatio: Double = 1.0, effectDescriptorChain: [EffectDescriptor] = [], volume: Double = 1, pan: Double = 0.5) {
        self.url = url
        self.name = name
        self.volume = volume
        self.pan = pan
        self.startTimeRatio = startTimeRatio
        self.endTimeRatio = endTimeRatio
        self.effectDescriptorChain = effectDescriptorChain
    }
}


