//
//  EffectRegistry.swift
//  MetroJuicePaak
//
//  Created by Noah Ang Shi Hern on 18/4/26.
//


class EffectRegistry {
    private var factories: [String: () -> DSPEffect] = [:]
    private var metadata: [String: EffectMetadata] = [:]

    func register<E: DSPEffect>(_ type: E.Type) {
        precondition(
            E.parameterDescriptors.count <= EffectLimits.maxParametersPerEffect,
            "\(E.identifier) declares \(E.parameterDescriptors.count) parameters; max is \(EffectLimits.maxParametersPerEffect)"
        )
        factories[E.identifier] = { E.init() }  
        metadata[E.identifier] = EffectMetadata(
            identifier: E.identifier,
            displayName: E.displayName,
            category: E.category,
            parameterDescriptors: E.parameterDescriptors
        )
    }

    func make(identifier: String) -> DSPEffect? {
        factories[identifier]?()
    }

    func allMetadata() -> [EffectMetadata] { Array(metadata.values) }
}

struct EffectMetadata {
    let identifier: String
    let displayName: String
    let category: EffectCategory
    let parameterDescriptors: [ParameterDescriptor]
}
