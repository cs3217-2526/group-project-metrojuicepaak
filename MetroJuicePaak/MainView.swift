//
//  MainView.swift
//  MetroJuicePaak
//
//  Created by Edwin Wong on 15/04/2026.
//

import SwiftUI

struct MainTabView: View {
    
    // Accept the fully initialized ViewModels from the @main App file
    var samplerOrchestrator: SamplerViewModel
    var sequencerViewModel: StepSequencerViewModel
    
    var body: some View {
        TabView {
            // MARK: - Tab 1: Sampler
            NavigationStack {
                SamplerView(orchestrator: samplerOrchestrator)
            }
            .tabItem {
                Label("Sampler", systemImage: "square.grid.2x2.fill")
            }
            
            // MARK: - Tab 2: Step Sequencer
            NavigationStack {
                StepSequencerView(viewModel: sequencerViewModel)
            }
            .tabItem {
                Label("Sequencer", systemImage: "slider.horizontal.3")
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .always)) // Changes it to swipeable dots
        .ignoresSafeArea(.keyboard, edges: .bottom)
        // Match the orange accent color used throughout your UI
        .tint(.orange)
    }
}
