//
//  EffectTypes.swift
//  MetroJuicePaak
//
//  Stub types for the DSP effect system.
//  These will be replaced when the full effect pipeline is implemented.
//

import AVFoundation

// MARK: - DSP Effect

protocol DSPEffect: AnyObject {
    func setParameter(id: String, value: Float)
}

// MARK: - Descriptor Types

struct EffectInstanceDescriptor {
    let id: UUID
    let effectIdentifier: String
    let parameterValues: [String: Float]
}

struct EffectChainDescriptor {
    let effects: [EffectInstanceDescriptor]
    static let empty = EffectChainDescriptor(effects: [])
}

// MARK: - Effect Registry

protocol EffectRegistry: AnyObject {
    func make(identifier: String) -> DSPEffect?
}

/// Stub registry that produces no effects until the DSP system is implemented.
final class StubEffectRegistry: EffectRegistry {
    func make(identifier: String) -> DSPEffect? { nil }
}

// MARK: - DSP Effect AU Bridge

enum DSPEffectAUBridgeError: Error {
    case notImplemented
}

final class DSPEffectAUBridge {
    static func makeAVAudioUnit(for effect: DSPEffect) async throws -> AVAudioUnit {
        throw DSPEffectAUBridgeError.notImplemented
    }
}
