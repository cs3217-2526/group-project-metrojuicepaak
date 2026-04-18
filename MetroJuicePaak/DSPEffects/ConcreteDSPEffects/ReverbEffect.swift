//
//  ReverbEffect.swift
//  MetroJuicePaak
//
//  Created by Noah Ang Shi Hern on 19/4/26.
//


//
//  ReverbEffect.swift
//  MetroJuicePaak
//

import Foundation
import Atomics

/// A Schroeder reverb — 4 parallel comb filters followed by 2 series all-pass filters.
///
/// This is the classic 1960s algorithm, simple and CPU-light but with character.
/// Mono internally (wet sum is duplicated to both channels); for a fancier stereo
/// version you'd detune the delays between left and right.
final class ReverbEffect: DSPEffect {

    // MARK: - Static metadata

    static let identifier = "com.metrojuicepaak.reverb"
    static let displayName = "Reverb"
    static let category: EffectCategory = .timeBased

    static let parameterDescriptors: [ParameterDescriptor] = [
        ParameterDescriptor(
            id: "size",
            displayName: "Size",
            minValue: 0.0,
            maxValue: 1.0,
            defaultValue: 0.5,
            unit: .unitless,
            taper: .linear,
            controlHint: .knob,
            valueLabels: nil
        ),
        ParameterDescriptor(
            id: "damping",
            displayName: "Damping",
            minValue: 0.0,
            maxValue: 1.0,
            defaultValue: 0.3,
            unit: .percent,
            taper: .linear,
            controlHint: .knob,
            valueLabels: nil
        ),
        ParameterDescriptor(
            id: "mix",
            displayName: "Mix",
            minValue: 0.0,
            maxValue: 1.0,
            defaultValue: 0.3,
            unit: .percent,
            taper: .linear,
            controlHint: .knob,
            valueLabels: nil
        )
    ]

    var latencySamples: Int { 0 }

    // MARK: - Atomic parameter store

    private let targetSizeBits = ManagedAtomic<UInt32>(Float(0.5).bitPattern)
    private let targetDampingBits = ManagedAtomic<UInt32>(Float(0.3).bitPattern)
    private let targetMixBits = ManagedAtomic<UInt32>(Float(0.3).bitPattern)

    // MARK: - Audio-thread state

    /// The four parallel comb filters. Classic Schroeder delay lengths
    /// scaled to the sample rate in prepare().
    private var combs: [CombFilter] = []

    /// Two series all-pass filters. Short, fixed delay lengths.
    private var allpasses: [AllpassFilter] = []

    private var smoothedSize: Float = 0.5
    private var smoothedDamping: Float = 0.3
    private var smoothedMix: Float = 0.3
    private var smoothingCoefficient: Float = 0.001

    // MARK: - DSPEffect

    required init() {}

    func prepare(sampleRate: Double, maxFrameCount: Int, channelCount: Int) {
        let fs = Float(sampleRate)

        let smoothingTimeSeconds: Float = 0.02
        smoothingCoefficient = 1.0 - expf(-1.0 / (fs * smoothingTimeSeconds))

        // Schroeder's original delay times, in seconds, tuned for musicality.
        // Prime-ish ratios so echoes from different combs don't line up.
        let combTimesSeconds: [Float] = [0.0297, 0.0371, 0.0411, 0.0437]
        let allpassTimesSeconds: [Float] = [0.005, 0.0017]

        combs = combTimesSeconds.map {
            CombFilter(maxDelaySamples: Int($0 * fs * 2) + 1,
                       delaySamples: Int($0 * fs))
        }
        allpasses = allpassTimesSeconds.map {
            AllpassFilter(maxDelaySamples: Int($0 * fs * 2) + 1,
                          delaySamples: Int($0 * fs))
        }

        smoothedSize = Float(bitPattern: targetSizeBits.load(ordering: .relaxed))
        smoothedDamping = Float(bitPattern: targetDampingBits.load(ordering: .relaxed))
        smoothedMix = Float(bitPattern: targetMixBits.load(ordering: .relaxed))
    }

    func reset() {
        for i in combs.indices { combs[i].clear() }
        for i in allpasses.indices { allpasses[i].clear() }
    }

    func process(context: DSPProcessContext) {
        let sizeTarget = Float(bitPattern: targetSizeBits.load(ordering: .relaxed))
        let dampingTarget = Float(bitPattern: targetDampingBits.load(ordering: .relaxed))
        let mixTarget = Float(bitPattern: targetMixBits.load(ordering: .relaxed))
        let alpha = smoothingCoefficient

        // Per-buffer smoothing is fine for reverb — the character changes
        // gradually anyway and per-sample wouldn't be audibly different.
        smoothedSize += (sizeTarget - smoothedSize) * alpha
        smoothedDamping += (dampingTarget - smoothedDamping) * alpha
        smoothedMix += (mixTarget - smoothedMix) * alpha

        // Map size [0, 1] → comb feedback [0.7, 0.98]. Higher = longer tail.
        let feedback = 0.7 + smoothedSize * 0.28
        // Damping [0, 1] directly controls the comb's internal lowpass.
        let damping = smoothedDamping
        let wet = smoothedMix
        let dry = 1.0 - wet

        // Set parameters on every filter for this buffer.
        for i in combs.indices {
            combs[i].feedback = feedback
            combs[i].damping = damping
        }

        // Reverb is naturally mono-in, mono-out for Schroeder topology.
        // We average the input channels into a single wet signal, then mix
        // it into both output channels.
        let channels = context.channelCount

        for i in 0..<context.frameCount {
            // Sum channels into mono input.
            var input: Float = 0
            for ch in 0..<channels {
                input += context.buffers[ch][i]
            }
            input /= Float(channels)

            // Parallel combs: sum their outputs.
            var combSum: Float = 0
            for c in 0..<combs.count {
                combSum += combs[c].process(input)
            }
            combSum *= 0.25  // normalize for 4 combs

            // Series all-passes: feed output of one into the next.
            var out = combSum
            for a in 0..<allpasses.count {
                out = allpasses[a].process(out)
            }

            // Mix wet signal back into every channel alongside the dry.
            for ch in 0..<channels {
                context.buffers[ch][i] = context.buffers[ch][i] * dry + out * wet
            }
        }
    }

    func setParameter(id: String, value: Float) {
        let clamped = max(0.0, min(1.0, value))
        switch id {
        case "size":    targetSizeBits.store(clamped.bitPattern, ordering: .relaxed)
        case "damping": targetDampingBits.store(clamped.bitPattern, ordering: .relaxed)
        case "mix":     targetMixBits.store(clamped.bitPattern, ordering: .relaxed)
        default: break
        }
    }
}

// MARK: - Comb Filter

/// A delay line with feedback and an internal one-pole lowpass in the
/// feedback path. The lowpass simulates high-frequency absorption in
/// real rooms — air and soft materials kill highs first, so a reverb
/// without damping sounds artificially "bright" on long tails.
private struct CombFilter {
    private var buffer: [Float]
    private var writeIndex: Int = 0
    private let delaySamples: Int

    /// Feedback gain — controls decay time. 0.7 = short, 0.98 = very long.
    var feedback: Float = 0.84

    /// Damping [0, 1] — higher = more high-frequency loss per pass.
    var damping: Float = 0.3

    /// Lowpass state for the feedback filter.
    private var lowpassState: Float = 0

    init(maxDelaySamples: Int, delaySamples: Int) {
        self.buffer = [Float](repeating: 0, count: maxDelaySamples)
        self.delaySamples = delaySamples
    }

    mutating func clear() {
        for i in buffer.indices { buffer[i] = 0 }
        lowpassState = 0
        writeIndex = 0
    }

    mutating func process(_ input: Float) -> Float {
        // Read from delaySamples in the past.
        var readIndex = writeIndex - delaySamples
        if readIndex < 0 { readIndex += buffer.count }
        let delayed = buffer[readIndex]

        // One-pole lowpass in the feedback path.
        lowpassState = delayed * (1.0 - damping) + lowpassState * damping

        // Write new value: input + filtered-feedback of delayed sample.
        buffer[writeIndex] = input + lowpassState * feedback

        writeIndex += 1
        if writeIndex >= buffer.count { writeIndex = 0 }

        return delayed
    }
}

// MARK: - All-pass Filter

/// An all-pass filter with flat magnitude response but scrambled phase.
/// Used to diffuse the output of the comb filters, turning "metallic pings"
/// into "smooth reverb tail". This is what gives Schroeder reverb its
/// signature character.
private struct AllpassFilter {
    private var buffer: [Float]
    private var writeIndex: Int = 0
    private let delaySamples: Int

    /// All-pass coefficient. 0.5 is classic Schroeder.
    var gain: Float = 0.5

    init(maxDelaySamples: Int, delaySamples: Int) {
        self.buffer = [Float](repeating: 0, count: maxDelaySamples)
        self.delaySamples = delaySamples
    }

    mutating func clear() {
        for i in buffer.indices { buffer[i] = 0 }
        writeIndex = 0
    }

    mutating func process(_ input: Float) -> Float {
        var readIndex = writeIndex - delaySamples
        if readIndex < 0 { readIndex += buffer.count }
        let delayed = buffer[readIndex]

        // Schroeder all-pass: y[n] = -g*x[n] + x[n-D] + g*y[n-D]
        // Rewritten so buffer stores v[n] = x[n] + g*v[n-D]:
        let v = input + gain * delayed
        buffer[writeIndex] = v
        let output = -gain * v + delayed

        writeIndex += 1
        if writeIndex >= buffer.count { writeIndex = 0 }

        return output
    }
}