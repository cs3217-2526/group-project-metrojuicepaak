//
//  AudioSample.swift
//  MetroJuicePaak
//
//  Created by Noah Ang Shi Hern on 22/3/26.
//

import Foundation

struct AudioSample: Codable {
    let url: URL
    let duration: TimeInterval
    
    init(url: URL, duration: TimeInterval) {
        self.url = url
        self.duration = duration
    }
}
