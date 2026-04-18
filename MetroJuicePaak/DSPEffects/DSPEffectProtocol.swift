//
//  DSPEffectProtocol.swift
//  MetroJuicePaak
//
//  Created by Noah Ang Shi Hern on 17/4/26.
//

enum EffectLimits {
    static let maxEffectsPerChain = 4
    static let maxParametersPerEffect = 6
}

enum EffectCategory: String, Codable, CaseIterable {
    case filter, dynamics, timeBased, modulation, distortion, utility
}

enum ParameterUnit: String, Codable {
    case hertz, decibels, seconds, milliseconds, percent, ratio, semitones, unitless
}

enum ParameterTaper: String, Codable {
    case linear       // uniform across the knob's travel
    case logarithmic  // for frequencies — 20 Hz to 20 kHz feels natural
    case exponential  // for times — short values get more resolution
}

struct ParameterDescriptor: Codable, Identifiable {
    let id: String
    let displayName: String
    let minValue: Float
    let maxValue: Float
    let defaultValue: Float
    let unit: ParameterUnit
    let taper: ParameterTaper
    let controlHint: ParameterControlHint
    let valueLabels: [String]?             
}

enum ParameterControlHint: String, Codable {
    case knob           // continuous rotary — default for most params
    case fader          // continuous linear — good for gain, mix
    case toggle         // boolean on/off — for bypass, phase invert
    case stepped        // discrete integer — for semitones, bit depth
    case indexed        // enum selector — for filter type, delay mode
}

struct DSPProcessContext {
    let buffers: UnsafeMutablePointer<UnsafeMutablePointer<Float>>
    let frameCount: Int
    let channelCount: Int
}

protocol DSPEffect: AnyObject {
    static var identifier: String { get }
    static var displayName: String { get }
    static var category: EffectCategory { get }
    
    /// At most 6. Enforced at registration.
    static var parameterDescriptors: [ParameterDescriptor] { get }
    
    init()

    /// Called once before the first `process` call, on the audio thread's
    /// preparation phase. Allocate all state here.
    func prepare(sampleRate: Double, maxFrameCount: Int, channelCount: Int)

    /// Zero all internal state. Called when a voice retriggers.
    func reset()

    /// Apply the effect in-place. Must not allocate or block.
    func process(context: DSPProcessContext)

    /// Receive a parameter change from the UI. Implementation must be
    /// lock-free — typically writes to an atomic that `process` reads.
    func setParameter(id: String, value: Float)

    /// Reported algorithmic latency in samples. 0 for most effects.
    var latencySamples: Int { get }
}


