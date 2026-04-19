//
//  LowpassEffect.swift
//  MetroJuicePaak
//
//  Created by Noah Ang Shi Hern on 18/4/26.
//

import Atomics
import Foundation
import Synchronization

/// A second-order biquad lowpass filter.
///
/// Two parameters:
///   - cutoff: 20 Hz to 20 kHz, logarithmic taper
///   - resonance (Q): 0.5 to 10, linear taper
///
/// Per-channel state (z1, z2) persists across process calls. Coefficients
/// are recomputed each buffer from the current (smoothed) cutoff and Q.
final class LowpassEffect: DSPEffect {

    // MARK: - Static metadata

    static let identifier = "com.metrojuicepaak.lowpass"
    static let displayName = "Lowpass"
    static let category: EffectCategory = .filter

    static let parameterDescriptors: [ParameterDescriptor] = [
        ParameterDescriptor(
            id: "cutoff",
            displayName: "Cutoff",
            minValue: 20.0,
            maxValue: 20_000.0,
            defaultValue: 1_000.0,
            unit: .hertz,
            controlHint: .knob,
            valueLabels: nil
        ),
        ParameterDescriptor(
            id: "resonance",
            displayName: "Resonance",
            minValue: 0.5,
            maxValue: 10.0,
            defaultValue: 0.707,
            unit: .unitless,
            controlHint: .knob,
            valueLabels: nil
        )
    ]

    var latencySamples: Int { 0 }

    // MARK: - Atomic parameter store

    private let targetCutoffBits = ManagedAtomic<UInt32>(Float(1_000.0).bitPattern)
    private let targetResonanceBits = ManagedAtomic<UInt32>(Float(0.707).bitPattern)

    // MARK: - Audio-thread state

    private var sampleRate: Float = 48_000

    /// Smoothed parameter values, updated per buffer.
    private var currentCutoff: Float = 1_000.0
    private var currentResonance: Float = 0.707

    private var smoothingCoefficient: Float = 0.001

    /// Biquad coefficients, recomputed per buffer from smoothed params.
    private var b0: Float = 1.0
    private var b1: Float = 0.0
    private var b2: Float = 0.0
    private var a1: Float = 0.0
    private var a2: Float = 0.0

    /// Per-channel state variables (z1, z2). Allocated in prepare.
    private var z1: [Float] = []
    private var z2: [Float] = []

    // MARK: - DSPEffect

    required init() {}

    func prepare(sampleRate: Double, maxFrameCount: Int, channelCount: Int) {
        self.sampleRate = Float(sampleRate)

        let smoothingTimeSeconds: Float = 0.01
        smoothingCoefficient = 1.0 - expf(-1.0 / (self.sampleRate * smoothingTimeSeconds))

        // Allocate per-channel state. NEVER allocate inside process().
        z1 = [Float](repeating: 0, count: channelCount)
        z2 = [Float](repeating: 0, count: channelCount)

        // Snap to targets on prepare.
        currentCutoff = Float(bitPattern: targetCutoffBits.load(ordering: .relaxed))
        currentResonance = Float(bitPattern: targetResonanceBits.load(ordering: .relaxed))
        recomputeCoefficients()
    }

    func process(context: DSPProcessContext) {
        // Read targets once per buffer.
        let cutoffTarget = Float(bitPattern: targetCutoffBits.load(ordering: .relaxed))
        let resonanceTarget = Float(bitPattern: targetResonanceBits.load(ordering: .relaxed))
        let alpha = smoothingCoefficient

        let chCount = min(context.channelCount, z1.count)

        for ch in 0..<chCount {
            let buf = context.buffers[ch]

            // Each channel maintains its own smoothed values so all channels
            // stay in sync — but in practice they track the same target.
            var localCutoff = currentCutoff
            var localResonance = currentResonance
            var s1 = z1[ch]
            var s2 = z2[ch]

            for i in 0..<context.frameCount {
                // Per-sample smoothing.
                localCutoff += (cutoffTarget - localCutoff) * alpha
                localResonance += (resonanceTarget - localResonance) * alpha

                // Recompute coefficients from the just-smoothed values.
                let freq = max(20.0, min(sampleRate * 0.49, localCutoff))
                let q = max(0.1, localResonance)
                let omega = 2.0 * Float.pi * freq / sampleRate
                let cosOmega = cosf(omega)
                let sinOmega = sinf(omega)
                let alphaQ = sinOmega / (2.0 * q)
                let a0Inv = 1.0 / (1.0 + alphaQ)

                let lb0 = ((1.0 - cosOmega) / 2.0) * a0Inv
                let lb1 = (1.0 - cosOmega) * a0Inv
                let lb2 = lb0
                let la1 = (-2.0 * cosOmega) * a0Inv
                let la2 = (1.0 - alphaQ) * a0Inv

                // Apply filter.
                let x = buf[i]
                let y = lb0 * x + s1
                s1 = lb1 * x - la1 * y + s2
                s2 = lb2 * x - la2 * y
                buf[i] = y
            }

            z1[ch] = s1
            z2[ch] = s2

            // Persist smoothed state for next buffer. Last channel wins,
            // but since they're all converging to the same target, this is fine.
            currentCutoff = localCutoff
            currentResonance = localResonance
        }
    }

    func setParameter(id: String, value: Float) {
        switch id {
        case "cutoff":
            let clamped = max(20.0, min(20_000.0, value))
            targetCutoffBits.store(clamped.bitPattern, ordering: .relaxed)
        case "resonance":
            let clamped = max(0.5, min(10.0, value))
            targetResonanceBits.store(clamped.bitPattern, ordering: .relaxed)
        default:
            break
        }
    }

    // MARK: - Coefficient computation (RBJ audio EQ cookbook, lowpass)

    private func recomputeCoefficients() {
        let freq = max(20.0, min(sampleRate * 0.49, currentCutoff))
        let q = max(0.1, currentResonance)

        let omega = 2.0 * Float.pi * freq / sampleRate
        let cosOmega = cosf(omega)
        let sinOmega = sinf(omega)
        let alphaQ = sinOmega / (2.0 * q)

        let a0Inv = 1.0 / (1.0 + alphaQ)

        b0 = ((1.0 - cosOmega) / 2.0) * a0Inv
        b1 = (1.0 - cosOmega) * a0Inv
        b2 = b0
        a1 = (-2.0 * cosOmega) * a0Inv
        a2 = (1.0 - alphaQ) * a0Inv
    }
}
