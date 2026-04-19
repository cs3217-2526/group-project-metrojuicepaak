//
//  EffectPanelView.swift
//  MetroJuicePaak
//
//  Created by Noah Ang Shi Hern on 18/4/26.
//

import SwiftUI

struct EffectPanelView: View {
    let effectInstance: EffectInstanceDescriptor
    let metadata: EffectMetadata
    let viewModel: EffectChainEditorViewModel

    var body: some View {
        HStack {
            ForEach(metadata.parameterDescriptors) { param in
                EffectParameterView(
                    descriptor: param,
                    currentValue: effectInstance.parameterValues[param.id]
                                  ?? param.defaultValue,
                    onChanged: { value in
                        viewModel.setParameterLive(
                            effectInstanceId: effectInstance.id,
                            parameterId: param.id,
                            value: value
                        )
                    },
                    onCommitted: { value in
                        viewModel.commitParameter(
                            effectInstanceId: effectInstance.id,
                            parameterId: param.id,
                            value: value
                        )
                    }
                )
            }
        }
    }
}
