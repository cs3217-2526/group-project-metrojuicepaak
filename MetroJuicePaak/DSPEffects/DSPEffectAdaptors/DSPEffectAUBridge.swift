//
//  DSPEffectAUBridge.swift
//  MetroJuicePaak
//
//  Created by Noah Ang Shi Hern on 18/4/26.
//

import AVFoundation

enum DSPEffectAUBridge {
    static let componentDescription = AudioComponentDescription(
        componentType: kAudioUnitType_Effect,
        componentSubType: fourCC("mjp1"),
        componentManufacturer: fourCC("MJPP"),
        componentFlags: 0,
        componentFlagsMask: 0
    )

    static func registerOnce() {
        // Register a factory that produces a DSPEffectAudioUnit wrapping
        // whichever DSPEffect we were asked for. Because AUAudioUnitFactory
        // doesn't take parameters, we use a thread-local or a small registry
        // that the init closure reads from.
        AUAudioUnit.registerSubclass(
            DSPEffectAudioUnit.self,
            as: componentDescription,
            name: "MetroJuicePaak DSP Effect",
            version: 1
        )
    }

    static func makeAVAudioUnit(for effect: DSPEffect) async throws -> AVAudioUnit {
        PendingEffect.next = effect
        return try await AVAudioUnit.instantiate(
            with: componentDescription,
            options: []
        )
    }
}

/// Ugly but necessary for AVAudioUnit's instantiate
enum PendingEffect {
    static var next: DSPEffect?
}

// MARK: - Private Helpers

func fourCC(_ string: String) -> UInt32 {
    let chars = Array(string.utf8)
    precondition(chars.count == 4, "FourCC must be exactly 4 ASCII characters")
    return UInt32(chars[0]) << 24
         | UInt32(chars[1]) << 16
         | UInt32(chars[2]) << 8
         | UInt32(chars[3])
}
