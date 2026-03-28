//
//  SampleEditorViewModel.swift
//  MetroJuicePaak
//
//  Created by proglab on 28/3/26.
//

import Foundation
import SwiftUI
import AVFoundation

@Observable
class SampleEditorViewModel {
    var waveformAmplitudes: [CGFloat] = []
    var startRatio: CGFloat = 0.0
    var endRatio: CGFloat = 1.0
    
    let pad: SamplerPad
    
    init(pad: SamplerPad) {
        self.pad = pad
        
        // Load existing trim boundaries if they exist
        if let sample = pad.sample, sample.duration > 0 {
            self.startRatio = CGFloat(sample.startTime / sample.duration)
            self.endRatio = CGFloat(sample.endTime / sample.duration)
        }
        
        extractAmplitudes()
    }
    
    private func extractAmplitudes() {
        guard let url = pad.sample?.url else { return }
        
        // Push the heavy file reading to a background thread
        Task.detached {
            do {
                let file = try AVAudioFile(forReading: url)
                let format = file.processingFormat
                let frameCount = AVAudioFrameCount(file.length)
                
                guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
                try file.read(into: buffer)
                
                guard let floatChannelData = buffer.floatChannelData else { return }
                let channelData = floatChannelData[0] // Use the left channel for visualization
                
                // Downsample: Group thousands of frames into 100 visual "buckets"
                let bucketCount = 100
                let framesPerBucket = Int(frameCount) / bucketCount
                var newAmplitudes: [CGFloat] = []
                
                for i in 0..<bucketCount {
                    var maxAmplitude: Float = 0.0
                    let startFrame = i * framesPerBucket
                    
                    // Find the peak amplitude in this specific bucket
                    for j in 0..<framesPerBucket where (startFrame + j) < Int(frameCount) {
                        let value = abs(channelData[startFrame + j])
                        if value > maxAmplitude {
                            maxAmplitude = value
                        }
                    }
                    newAmplitudes.append(CGFloat(maxAmplitude))
                }
                
                // Push the final array back to the main thread to update the UI
                await MainActor.run {
                    self.waveformAmplitudes = newAmplitudes
                }
            } catch {
                print("❌ Failed to extract waveform: \(error)")
            }
        }
    }
    
    // Convert ratios back to real time and save
    func saveEdits() {
        guard var sample = pad.sample else { return }
        sample.startTime = TimeInterval(startRatio) * sample.duration
        sample.endTime = TimeInterval(endRatio) * sample.duration
        pad.sample = sample
    }
}
