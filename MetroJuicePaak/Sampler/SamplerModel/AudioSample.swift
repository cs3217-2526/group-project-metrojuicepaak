//
//  AudioSample.swift
//  MetroJuicePaak
//
//  Created by Noah Ang Shi Hern on 22/3/26.
//

import Foundation

struct AudioSample: Codable {
    let url: URL
    let id: String
    let duration: TimeInterval
    
    var startTime: TimeInterval
    var endTime: TimeInterval
    
    init(id: String, url: URL, duration: TimeInterval) {
        self.id = id
        self.url = url
        self.duration = duration
        
        self.startTime = 0.0
        self.endTime = duration
    }
}
