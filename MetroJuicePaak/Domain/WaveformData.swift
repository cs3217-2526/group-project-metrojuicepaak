//
//  WaveformData.swift
//  MetroJuicePaak
//
//  Created by Noah Ang Shi Hern on 4/4/26.
//

import Foundation

/// Normalized amplitude data produced by WaveformGenerationService for visualization.
/// All points are in the range [0.0, 1.0].
struct WaveformData {
    let points: [Float]
}
