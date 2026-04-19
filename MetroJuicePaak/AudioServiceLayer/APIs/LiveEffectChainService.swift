//
//  EffectManagementService.swift
//  MetroJuicePaak
//
//  Created by Noah Ang Shi Hern on 18/4/26.
//

import Foundation


protocol LiveEffectChainService {
    /// Rebuilds the live DSP chain to match the sample's current descriptor.
    /// The engine reads `sample.effectDescriptorChain` directly — the caller
    /// doesn't extract and pass it separately.
    func rebuildEffectChain(for sample: EffectableAudioSample) async throws

    /// Routes a single parameter change to the live effect on the audio thread.
    /// The three value arguments remain because they describe a specific atomic
    /// change that isn't derivable from the sample's state — this is the LIVE
    /// path, not the descriptor path.
    func updateEffectParameter(
        for sample: EffectableAudioSample,
        effectInstanceId: UUID,
        parameterId: String,
        value: Float
    )
}
