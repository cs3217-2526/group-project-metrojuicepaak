////
////  SamplerPad.swift
////  MetroJuicePaak
////
////  Created by Noah Ang Shi Hern on 22/3/26.
////
//
//import Foundation
//import AVFoundation
//
//protocol SamplerPadDelegate: AnyObject {
//    func didSampleLoad(didSelectPad id: ObjectIdentifier)
//    func didSamplePlay(didSelectPad id: ObjectIdentifier)
//}
//
//class SamplerPad: Identifiable, Codable {
//    let id: UUID //for persistence
//    var sample: AudioSample?
//    
//    var isSampleLoaded: Bool {
//        sample != nil
//    }
//    
//    var sampleID: String? {
//        sample?.id
//    }
//    
//    init(id: UUID = UUID(), sample: AudioSample? = nil) {
//        self.id = id
//        self.sample = sample
//    }
//    
//    func loadAudioSample(from url: URL, id: String) {
//        var realDuration: TimeInterval = 1.0
//        
//        // Calculate the actual duration of the file
//        if let file = try? AVAudioFile(forReading: url) {
//            realDuration = Double(file.length) / file.processingFormat.sampleRate
//        }
//        
//        let sample = AudioSample(id: id, url: url, duration: realDuration)
//        self.sample = sample
//    }
//}
