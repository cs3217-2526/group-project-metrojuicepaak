//
//  EffectTypes.swift
//  MetroJuicePaak
//
//  Adaptors to the AUAudioUnit
//
//

import AVFoundation

final class DSPEffectAudioUnit: AUAudioUnit {

    // MARK: - Stored state

    private var effect: DSPEffect
    private let maxFrames: AUAudioFrameCount = 4096

    private var inputBus: AUAudioUnitBus!
    private var outputBus: AUAudioUnitBus!
    private var inputBusArray: AUAudioUnitBusArray!
    private var outputBusArray: AUAudioUnitBusArray!

    // Pulled from upstream each render cycle.
    private var pullInputBlock: AURenderPullInputBlock?

    // Scratch buffer for pulling input when we can't render in place.
    private var pcmBuffer: AVAudioPCMBuffer!

    // MARK: - Init
    override init(componentDescription: AudioComponentDescription,
                  options: AudioComponentInstantiationOptions = []) throws {
        guard let effect = PendingEffect.next else {
            fatalError("No pending DSPEffect set before instantiation")
        }
        PendingEffect.next = nil
        self.effect = effect
        try super.init(componentDescription: componentDescription, options: options)

        let format = AVAudioFormat(standardFormatWithSampleRate: 48_000,
                                   channels: 2)!
        inputBus  = try AUAudioUnitBus(format: format)
        outputBus = try AUAudioUnitBus(format: format)
        inputBus.maximumChannelCount  = 2
        outputBus.maximumChannelCount = 2

        inputBusArray  = AUAudioUnitBusArray(audioUnit: self,
                                             busType: .input,
                                             busses: [inputBus])
        outputBusArray = AUAudioUnitBusArray(audioUnit: self,
                                             busType: .output,
                                             busses: [outputBus])

        self.maximumFramesToRender = maxFrames
    }

    override var inputBusses:  AUAudioUnitBusArray { inputBusArray }
    override var outputBusses: AUAudioUnitBusArray { outputBusArray }

    // MARK: - Allocate / deallocate

    override func allocateRenderResources() throws {
        try super.allocateRenderResources()

        let format = outputBus.format
        pcmBuffer = AVAudioPCMBuffer(pcmFormat: format,
                                     frameCapacity: maxFrames)!

        effect.prepare(sampleRate: format.sampleRate,
                       maxFrameCount: Int(maxFrames),
                       channelCount: Int(format.channelCount))
    }

    override func deallocateRenderResources() {
        pcmBuffer = nil
        super.deallocateRenderResources()
    }

    // MARK: - Latency

    override var latency: TimeInterval {
        Double(effect.latencySamples) / outputBus.format.sampleRate
    }

    // MARK: - Render block
    //
    // This closure runs on the real-time audio thread. No allocation,
    // no locks, no Swift runtime calls that could allocate. Captures
    // must be `unowned` or raw pointers.

    override var internalRenderBlock: AUInternalRenderBlock {
        let effectRef = effect
        let channels  = Int(outputBus.format.channelCount)

        return { actionFlags, timestamp, frameCount, outputBusNumber,
                 outputData, realtimeEventListHead, pullInputBlock in

            guard let pullInput = pullInputBlock else {
                return kAudioUnitErr_NoConnection
            }

            // 1. Pull input from upstream into outputData.
            var pullFlags: AudioUnitRenderActionFlags = []
            let pullStatus = pullInput(&pullFlags, timestamp, frameCount, 0, outputData)
            guard pullStatus == noErr else { return pullStatus }

            // 2. Collect per-channel pointers into a contiguous array.
            //    We know channels <= 2 for stereo, but this generalises.
            let ablPointer = UnsafeMutableAudioBufferListPointer(outputData)

            // Stack-allocate the array of channel pointers.
            // withUnsafeTemporaryAllocation avoids heap allocation on the audio thread.
            withUnsafeTemporaryAllocation(
                of: UnsafeMutablePointer<Float>.self,
                capacity: channels
            ) { channelPointers in
                for i in 0..<channels {
                    guard let raw = ablPointer[i].mData else {
                        // Shouldn't happen — means the host gave us a null buffer.
                        return
                    }
                    channelPointers[i] = raw.assumingMemoryBound(to: Float.self)
                }

                // 3. Call process ONCE with all channels visible.
                let context = DSPProcessContext(
                    buffers: channelPointers.baseAddress!,
                    frameCount: Int(frameCount),
                    channelCount: channels
                )
                effectRef.process(context: context)
            }

            return noErr
        }
    }
}



