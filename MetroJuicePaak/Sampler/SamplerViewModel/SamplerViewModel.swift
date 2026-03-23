//
//  SamplerViewModel.swift
//  MetroJuicePaak
//
//  Created by Noah Ang Shi Hern on 22/3/26.
//

import Foundation
import Observation

@Observable
class SamplerViewModel {
    private let audioService: AudioService
    private var audioTempFileStore = AudioTempFileStore()
    
    private(set) var pads: [UUID: SamplerPad] = [:]
    
    var isRecording: Bool = false
    var isPlaying: Bool = false
    
    init(audioService: AudioService) {
        
        self.audioService = audioService
        
        // Create initial pads
        let initialPads = (0..<16).map { _ in
            SamplerPad(id: UUID())
        }
        
        // Store in dictionary
        pads = Dictionary(uniqueKeysWithValues: initialPads.map { ($0.id, $0) })
    }
    
    // MARK: - Public API for SamplerPads
    
    func handlePadPressed(_ padId: UUID) async {
        guard let pad = pads[padId] else {
            print("❌ Pad not found: \(padId)")
            return
        }
        
        if pad.isSampleLoaded {
            print("🎵 Playing sample on pad: \(padId)")
            await audioService.playAudio(identifier: pad.sampleID!)
        } else {
            if isRecording {
                print("⚠️ Already recording, ignoring pad press")
                return
            } else {
                do {
                    let url = audioTempFileStore.makeURL(filename: padId.uuidString, extension: "m4a")
                    print("🎙️ Starting recording for pad: \(padId)")
                    let recordingStarted = try await audioService.recordAudio(url: url)
                    if recordingStarted {
                        isRecording = true
                        print("✅ Recording started for pad: \(padId)")
                    } else {
                        print("❌ Recording failed to start for pad: \(padId)")
                    }
                } catch {
                    // Handle recording error (e.g., permission denied, audio session issues)
                    print("❌ Failed to start recording: \(error)")
                }
            }
        }
    }
    
    func handlePadReleased(_ padId: UUID) async {
        guard let pad = pads[padId] else {
            print("❌ Pad not found: \(padId)")
            return
        }
        
        if pad.isSampleLoaded {
            print("⏹️ Stopping playback on pad: \(padId)")
            await audioService.stopAudio(identifier: pad.sampleID!)
        } else {
            if !isRecording {
                print("⚠️ Not recording, ignoring pad release")
                return
            } else {
                print("⏹️ Stopping recording for pad: \(padId)")
                if let audioFileURL = await audioService.stopRecording() {
                    print("💾 Loading sample into pad: \(padId)")
                    pads[padId]?.loadAudioSample(from: audioFileURL, id: padId.uuidString)
                    isRecording = false
                    
                    do {
                        try await audioService.loadAudio(from: audioFileURL, identifier: padId.uuidString)
                        print("✅ Sample loaded successfully for pad: \(padId)")
                    } catch {
                        // Handle audio loading error
                        print("❌ Failed to load audio: \(error)")
                        // Clear the sample from the pad since loading failed
                        pads[padId]?.sample = nil
                    }
                } else {
                    print("❌ No recording URL returned")
                    return
                }
            }
        }
    }
}



