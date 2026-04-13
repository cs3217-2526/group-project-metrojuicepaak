//
//  SampleVoice.swift
//  MetroJuicePaak
//
//  Created by Noah Ang Shi Hern on 13/4/26.
//


// SampleVoice.swift
// Imports AVFoundation — part of the service/bridging boundary.

import AVFoundation
import Foundation

/// One voice per AudioSample that's currently loaded.
/// Owns the player node, the live DSPEffect instances, and the AVAudioUnit
/// wrappers. Responsible for constructing, rebuilding, and tearing down
/// the effect chain for its sample.
final class SampleVoice {

    // MARK: - Collaborators (injected)

    private unowned let engine: AVAudioEngine
    private unowned let registry: EffectRegistry
    private let bridge: DSPEffectAUBridge.Type

    // MARK: - Audio graph state

    /// The player node for this sample. Attached to the engine for the
    /// voice's lifetime. Scheduled with the audio file on start().
    let playerNode: AVAudioPlayerNode

    /// The audio file this voice plays. Read from disk in loadFile().
    private var audioFile: AVAudioFile?

    /// The current chain's live effects, in order. Parallel to `effectUnits`.
    /// Indexed by position; parameter lookups use `effectsByInstanceId` instead.
    private var liveEffects: [DSPEffect] = []

    /// The AVAudioUnit wrappers attached to the engine, in chain order.
    /// Parallel to `liveEffects`.
    private var effectUnits: [AVAudioUnit] = []

    /// Lookup from stable instance id (the UUID on EffectInstanceDescriptor)
    /// to the corresponding live effect. Used for O(1) parameter routing
    /// without walking the chain.
    private var effectsByInstanceId: [UUID: DSPEffect] = [:]

    /// The format the engine uses for this voice's connections.
    /// Captured from the player node's output format on first build.
    private var connectionFormat: AVAudioFormat?

    // MARK: - Init / deinit

    init(engine: AVAudioEngine,
         registry: EffectRegistry,
         bridge: DSPEffectAUBridge.Type = DSPEffectAUBridge.self) {
        self.engine = engine
        self.registry = registry
        self.bridge = bridge
        self.playerNode = AVAudioPlayerNode()
    }

    deinit {
        // Defensive teardown; voices should normally be torn down explicitly
        // via detach() before being released so the engine graph stays clean.
    }

    // MARK: - Lifecycle

    /// Load the audio file and attach the player node to the engine.
    /// Called once when the voice is first constructed.
    func loadFile(from url: URL) throws {
        let file = try AVAudioFile(forReading: url)
        self.audioFile = file
        engine.attach(playerNode)
        self.connectionFormat = file.processingFormat
    }

    /// Build the effect chain from a descriptor and connect the graph.
    /// Called after loadFile, and again whenever the chain structurally changes.
    func rebuildChain(_ chain: EffectChainDescriptor) async throws {
        guard let format = connectionFormat else {
            throw SampleVoiceError.notLoaded
        }

        // 1. Tear down the existing chain.
        disconnectAndDetachCurrentChain()

        // 2. Construct fresh live effects and their AU wrappers for each
        //    descriptor entry.
        var newEffects: [DSPEffect] = []
        var newUnits: [AVAudioUnit] = []
        var newLookup: [UUID: DSPEffect] = [:]

        for instance in chain.effects {
            guard let effect = registry.make(identifier: instance.effectIdentifier) else {
                // An identifier in the descriptor doesn't exist in the registry.
                // Could happen after removing an effect type between project saves.
                // Skip this entry and continue; log in real code.
                continue
            }

            // Apply stored parameter values before the effect starts rendering.
            // These go into the live effect's atomics so that when prepare and
            // process run later, the smoothed-from values start at the stored ones.
            for (parameterId, value) in instance.parameterValues {
                effect.setParameter(id: parameterId, value: value)
            }

            // Wrap into an engine-attachable AVAudioUnit via the bridge.
            let auUnit = try await bridge.makeAVAudioUnit(for: effect)

            engine.attach(auUnit)

            newEffects.append(effect)
            newUnits.append(auUnit)
            newLookup[instance.id] = effect
        }

        self.liveEffects = newEffects
        self.effectUnits = newUnits
        self.effectsByInstanceId = newLookup

        // 3. Wire player -> effects in series -> main mixer.
        var previous: AVAudioNode = playerNode
        for unit in newUnits {
            engine.connect(previous, to: unit, format: format)
            previous = unit
        }
        engine.connect(previous, to: engine.mainMixerNode, format: format)

        // 4. The engine will call allocateRenderResources on each new AU
        //    on its own when it next prepares for rendering, which triggers
        //    prepare() on each DSPEffect and allocates their live state.
        //    If the engine is already running, this happens immediately.
    }

    /// Detach the voice from the engine entirely. Called when the refcount
    /// drops to zero in AudioService.
    func detach() {
        if playerNode.isPlaying {
            playerNode.stop()
        }
        disconnectAndDetachCurrentChain()
        engine.disconnectNodeOutput(playerNode)
        engine.detach(playerNode)
        audioFile = nil
    }

    // MARK: - Playback

    func start() {
        guard let file = audioFile else { return }
        // Schedule the file from the beginning. For retrigger scenarios
        // you'd stop the player first; for overlapping playback you'd need
        // a pool of player nodes (not covered here).
        playerNode.stop()
        playerNode.scheduleFile(file, at: nil, completionHandler: nil)
        if !engine.isRunning {
            try? engine.start()
        }
        playerNode.play()
    }

    func stop() {
        playerNode.stop()
    }

    // MARK: - Parameter updates (live, from the UI thread)

    /// Route a parameter change to the correct live effect instance.
    /// Called from AudioService in response to a view model knob update.
    /// The underlying setParameter call is lock-free (atomic store), so
    /// this is safe to call from the main thread while the audio thread
    /// is mid-render.
    func setParameter(effectInstanceId: UUID,
                      parameterId: String,
                      value: Float) {
        guard let effect = effectsByInstanceId[effectInstanceId] else {
            // The instance id isn't in the current chain. This can happen
            // if the chain was rebuilt between the UI gesture and the
            // parameter update arriving. Drop silently.
            return
        }
        effect.setParameter(id: parameterId, value: value)
    }

    // MARK: - Private

    private func disconnectAndDetachCurrentChain() {
        // Disconnect everything from the player node onward. Order matters:
        // detach in reverse of attach, disconnect before detach.
        for unit in effectUnits {
            engine.disconnectNodeOutput(unit)
            engine.disconnectNodeInput(unit)
        }
        engine.disconnectNodeOutput(playerNode)
        for unit in effectUnits {
            engine.detach(unit)
        }
        liveEffects.removeAll()
        effectUnits.removeAll()
        effectsByInstanceId.removeAll()
    }
}

// MARK: - Errors

enum SampleVoiceError: Error {
    case notLoaded
}
