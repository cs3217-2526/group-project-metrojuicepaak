//
//  SamplerPadButtonUIElements.swift
//  MetroJuicePaak
//
//  Created by Noah Ang Shi Hern on 23/3/26.
//

import SwiftUI

struct SamplerPadButtonUIElements {
    let color: SamplerPadColour
    let image: UIImage?
    
    init(color: SamplerPadColour = .blue, imageName: String = "pad-button") {
        self.color = color
        self.image = UIImage(named: imageName)
    }
}
