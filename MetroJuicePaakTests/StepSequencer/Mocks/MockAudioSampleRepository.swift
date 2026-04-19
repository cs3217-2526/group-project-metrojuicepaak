//
//  MockAudioSampleRepository.swift
//  MetroJuicePaak
//
//  Created by Edwin Wong on 18/04/2026.
//


import Foundation
@testable import MetroJuicePaak

final class MockAudioSampleRepository: ReadableAudioSampleRepository {
    
    var allSamples: [PlayableAudioSample & NamedAudioSample] = []
    
    func getPlayableSample(for id: ObjectIdentifier) -> PlayableAudioSample? {
        return nil
    }
    
    func getNamedSample(for id: ObjectIdentifier) -> (PlayableAudioSample & NamedAudioSample)? {
        return nil
    }
}

class DummySample {}
