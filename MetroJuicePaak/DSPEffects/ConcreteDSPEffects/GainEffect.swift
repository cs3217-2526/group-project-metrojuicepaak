//
//  GainEffect.swift
//  MetroJuicePaak
//
//  Created by Noah Ang Shi Hern on 18/4/26.
//

import Atomics
import Foundation
import Synchronization

/// A simple linear gain effect.
///
/// One parameter: gain in decibels, -60 dB to +12 dB.
/// Converted internally to a linear multiplier and smoothed per-sample
/// to avoid zipper noise on parameter changes.
final class GainEffect: DSPEffect {

    // MARK: - Static metadata

    static let identifier = "com.metrojuicepaak.gain"
    static let displayName = "Gain"
    static let category: EffectCategory = .utility

    static let parameterDescriptors: [ParameterDescriptor] = [
        ParameterDescriptor(
            id: "gain",
            displayName: "Gain",
            minValue: -60.0,
            maxValue: 12.0,
            defaultValue: 0.0,
            unit: .decibels,
            taper: .linear,
            controlHint: .fader,
            valueLabels: nil
        )
    ]

    var latencySamples: Int { 0 }

    // MARK: - Atomic parameter store (UI thread → audio thread)

    /// Target gain as a LINEAR multiplier, stored as the bit pattern of a Float.
    /// UI writes via setParameter; audio thread reads at the top of process.
    /// Initialized to 1.0 (0 dB = unity gain).
    private let targetLinearGainBits = ManagedAtomic<UInt32>(Float(1.0).bitPattern)
    

    // MARK: - Audio-thread state (touched only inside process)

    /// The currently-applied gain, smoothed toward the target each sample.
    private var currentLinearGain: Float = 1.0

    /// Smoothing coefficient — controls how quickly currentLinearGain
    /// converges toward the target. Set in prepare based on sample rate.
    /// Higher = faster (more zipper risk), lower = slower (more lag).
    private var smoothingCoefficient: Float = 0.001

    // MARK: - DSPEffect

    required init() {}

    func prepare(sampleRate: Double, maxFrameCount: Int, channelCount: Int) {
        // ~5 ms smoothing time constant. Tweak to taste.
        let smoothingTimeSeconds: Float = 0.005
        smoothingCoefficient = 1.0 - expf(-1.0 / (Float(sampleRate) * smoothingTimeSeconds))

        // Snap current gain to current target on prepare (no audible ramp on load).
        let target = Float(bitPattern: targetLinearGainBits.load(ordering: .relaxed))
        currentLinearGain = target
    }

    func reset() {
        // Snap to target on retrigger — no residual smoothing state carries over.
        let target = Float(bitPattern: targetLinearGainBits.load(ordering: .relaxed))
        currentLinearGain = target
    }

    func process(context: DSPProcessContext) {
        // Load target once per buffer. Reading the atomic per-sample would be
        // more responsive but costs more; per-buffer is plenty for a knob.
        let target = Float(bitPattern: targetLinearGainBits.load(ordering: .relaxed))
        let alpha = smoothingCoefficient

        var gain = currentLinearGain

        for ch in 0..<context.channelCount {
            let buf = context.buffers[ch]
            gain = currentLinearGain    // reset per-channel so all channels track same smoothing

            for i in 0..<context.frameCount {
                // One-pole smoothing: gain drifts toward target exponentially.
                gain += (target - gain) * alpha
                buf[i] *= gain
            }
        }

        // Persist the smoothed-to value for the next buffer to continue from.
        currentLinearGain = gain
    }

    func setParameter(id: String, value: Float) {
        guard id == "gain" else { return }
        // Convert dB → linear. 20 * log10(v) = dB  ⇒  v = 10^(dB/20)
        let clampedDB = max(-60.0, min(12.0, value))
        let linear = powf(10.0, clampedDB / 20.0)
        targetLinearGainBits.store(linear.bitPattern, ordering: .relaxed)
    }
}
