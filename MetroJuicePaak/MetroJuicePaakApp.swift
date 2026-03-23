//
//  MetroJuicePaakApp.swift
//  MetroJuicePaak
//
//  Created by Noah Ang Shi Hern on 17/3/26.
//

import SwiftUI

@main
struct MetroJuicePaakApp: App {
    //let audioService = AudioService()
    let samplerViewModel =  SamplerViewModel()
    var body: some Scene {
        WindowGroup {
            SamplerView(viewModel: samplerViewModel)
        }
    }
}
