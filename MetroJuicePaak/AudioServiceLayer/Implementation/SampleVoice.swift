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
    private let playerNode: AVAudioPlayerNode

    /// The audio file this voice plays. Read from disk in loadFile().
    private var audioFile: AVAudioFile?
    
    //  The Master RAM Storage
    private var masterBuffer: AVAudioPCMBuffer?

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
        
        let format = file.processingFormat
        let frameCount = AVAudioFrameCount(file.length)
        
        // 🟢 Read the disk ONCE and store the entire file in RAM
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw SampleVoiceError.notLoaded
        }
        try file.read(into: buffer)
        self.masterBuffer = buffer
        
        // 1. Attach the node
        engine.attach(playerNode)
        self.connectionFormat = file.processingFormat
        
        // 2. THE FIX: Create a valid audio graph immediately!
        // Connect the player directly to the main mixer so engine.start() doesn't crash.
        engine.connect(playerNode, to: engine.mainMixerNode, format: file.processingFormat)
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

    /// Schedules playback of the loaded sample at a precise hardware timestamp,
    /// with optional trim. Used by the sequencer's lookahead scheduler to line
    /// up step triggers against the audio clock.
    ///
    /// Any playback currently in progress on this voice is cancelled when the
    /// new buffer is scheduled (`.interrupts`). If the engine is not yet running,
    /// it is started lazily on first trigger.
    ///
    /// - Parameters:
    ///   - time: Absolute host-clock time (seconds) at which rendering of the
    ///     first frame should begin. Typically a near-future timestamp produced
    ///     by the sequencer's scheduler.
    ///   - startTimeRatio: Normalised start of the trimmed region, in [0, 1].
    ///     Defaults to 0 (sample start).
    ///   - endTimeRatio: Normalised end of the trimmed region, in [0, 1].
    ///     Defaults to 1 (sample end).
    ///
    /// - Note: The trim is realised by slicing the master PCM buffer (held in
    ///   RAM since ``loadFile(from:)``) into a fresh cropped buffer per call.
    ///   When the ratios are the defaults 0 / 1, the master buffer is scheduled
    ///   directly with no copy (fast path). A zero-length trim is silently
    ///   dropped, as ``AVAudioEngine`` raises on an empty buffer.
    func start(at time: TimeInterval, startTimeRatio: Double = 0.0, endTimeRatio: Double = 1.0) {
        playerNode.stop()
        
        // 1. Slice the required segment out of RAM instantly
        guard let buffer = getTrimmedBuffer(startTimeRatio: startTimeRatio, endTimeRatio: endTimeRatio) else { return }
        
        // 2. Convert to hardware clock time
        let hostTime = AudioTimeConverter.hostTimeFrom(timeInterval: time)
        let avTime = AVAudioTime(hostTime: hostTime)
        
        // 3. Schedule the RAM buffer
        playerNode.scheduleBuffer(buffer, at: avTime, options: .interrupts, completionHandler: nil)
        
        if !engine.isRunning { try? engine.start() }
        playerNode.play()
    }

    /// Schedules immediate playback of the loaded sample, with optional trim.
    /// Used by the sampler pads for zero-latency response to taps.
    ///
    /// Behaviourally identical to ``start(at:startTimeRatio:endTimeRatio:)``
    /// but without a scheduled start time — the buffer plays as soon as the
    /// engine's render cycle consumes it. Use the timestamped overload when
    /// you need to align playback against a shared clock (the sequencer);
    /// use this one when "now" is good enough (pad taps).
    ///
    /// - Parameters:
    ///   - startTimeRatio: Normalised start of the trimmed region, in [0, 1].
    ///   - endTimeRatio: Normalised end of the trimmed region, in [0, 1].
    /// Immediate playback for the Sampler pads
    func start(startTimeRatio: Double = 0.0, endTimeRatio: Double = 1.0) {
        playerNode.stop()
        guard let buffer = getTrimmedBuffer(startTimeRatio: startTimeRatio, endTimeRatio: endTimeRatio) else { return }
        
        playerNode.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        
        if !engine.isRunning { try? engine.start() }
        playerNode.play()
    }
    
    func setVolume(_ volume: Float) {
        self.playerNode.volume = volume
    }
    
    func setPan(_ pan: Float) {
        self.playerNode.pan = pan
    }
    
    var isPlaying: Bool {
        self.playerNode.isPlaying
    }
    
    // MARK: - RAM Buffer Slicing

    /// Safely copies the exact frames needed from the master buffer into a temporary playback buffer.
    private func getTrimmedBuffer(startTimeRatio: Double, endTimeRatio: Double) -> AVAudioPCMBuffer? {
        guard let master = masterBuffer else { return nil }
        
        // Fast-path: If the user hasn't edited the trim markers, just play the whole master buffer!
        if startTimeRatio == 0.0 && endTimeRatio == 1.0 {
            return master
        }
        
        let totalFrames = Double(master.frameLength)
        let startFrame = AVAudioFramePosition(totalFrames * startTimeRatio)
        let frameCount = AVAudioFrameCount(totalFrames * (endTimeRatio - startTimeRatio))
        
        guard frameCount > 0,
              let croppedBuffer = AVAudioPCMBuffer(pcmFormat: master.format, frameCapacity: frameCount) else {
            return nil
        }
        
        croppedBuffer.frameLength = frameCount
        
        // Perform a lightning-fast memory copy for each audio channel
        for channel in 0..<Int(master.format.channelCount) {
            guard let masterData = master.floatChannelData?[channel],
                  let croppedData = croppedBuffer.floatChannelData?[channel] else { continue }
            
            // Advance the pointer to the start frame and copy the data
            let sourcePointer = masterData.advanced(by: Int(startFrame))
            croppedData.update(from: sourcePointer, count: Int(frameCount))
        }
        
        return croppedBuffer
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
