import Foundation
import AVFoundation

// MARK: - WaveformData

/// Normalized amplitude data for visualizing an audio sample.
///
/// Values are in `[0, 1]`, where each entry represents the peak absolute
/// amplitude of the corresponding bucket of audio frames in the source file.
///
/// **Resolution contract.** A `WaveformData` produced by `WaveformCache` for
/// a request of `resolution: N` always contains exactly `N` points. When the
/// requested resolution exceeds the number of available frames, the surplus
/// buckets contain zero (no frames to scan). Consumers can detect this case
/// via ``isSparse`` and choose their own fallback rendering strategy if the
/// literal comb pattern is unsuitable.
struct WaveformData: Equatable, Sendable {
    let points: [Float]

    var resolution: Int {
        points.count
    }

    static let empty = WaveformData(points: [])
}

extension WaveformData {
    /// The number of points containing actual sampled audio, as opposed to
    /// gap points produced when the requested resolution exceeded the
    /// available frame count.
    ///
    /// Equal to ``resolution`` for normal samples; smaller for very short
    /// samples rendered at high resolution.
    var nonEmptyPointCount: Int {
        points.lazy.filter { $0 > 0 }.count
    }

    /// True when fewer than half of the waveform's points contain audio.
    ///
    /// This is a hint, not a contract — consumers may use it to fall back
    /// to a different rendering strategy (interpolation, wider bars, a
    /// lower-resolution re-request) when a sample is too short to fill the
    /// requested resolution.
    var isSparse: Bool {
        guard !points.isEmpty else { return false }
        return nonEmptyPointCount < points.count / 2
    }
}

// MARK: - Cache key

/// A value-type fingerprint of a waveform request.
///
/// The cache is keyed by this struct rather than by `WaveformSource` directly
/// because `WaveformSource` is a protocol — it cannot serve as a dictionary
/// key, and even if it could, reference-based equality on conforming class
/// types would prevent two `AudioSample` instances pointing at the same file
/// with the same trim from sharing a cache entry.
///
/// The cache's notion of identity is `(url, startTimeRatio, endTimeRatio,resolution)
/// Any two requests matching on those four fields return the
/// same waveform, regardless of which `WaveformSource` instance was passed
/// in. This struct captures that identity.
private struct WaveformCacheKey: Hashable {
    let url: URL
    let startTimeRatio: Double
    let endTimeRatio: Double
    let resolution: Int

    init(source: WaveformSource, resolution: Int) {
        self.url = source.url
        self.startTimeRatio = source.startTimeRatio
        self.endTimeRatio = source.endTimeRatio
        self.resolution = resolution
    }
}

// MARK: - WaveformCache

/// Caches generated waveforms and serves repeated requests without redoing
/// the decode/reduce work.
///
/// Implemented as an `actor` so that the internal cache dictionary and the
/// in-flight task table are accessed under language-enforced isolation. All
/// public entry points are `async` because the underlying decode is genuinely
/// expensive (tens to hundreds of milliseconds for multi-second clips) and
/// must not run on the main thread.
///
/// **Resolution contract.** The cache always returns a `WaveformData` whose
/// `resolution` equals the resolution that was requested. When the request
/// exceeds the available frame count, the surplus points are zero. This
/// keeps the cache contract honest — a request for 500 points always returns
/// 500 points — and lets consumers handle the sparse case with whatever
/// fallback fits their UI. See ``WaveformData/isSparse``.
///
/// **In-flight deduplication.** If two callers request the same waveform
/// simultaneously, the second caller awaits the same `Task` the first
/// caller started rather than kicking off a parallel decode. Once the task
/// completes, its result is moved into `cache` and the `inFlight` entry is
/// cleared.
actor WaveformCache: WaveformGenerationService {

    // MARK: Storage

    /// Completed waveforms, keyed by request fingerprint.
    private var cache: [WaveformCacheKey: WaveformData] = [:]

    /// In-progress decode tasks, keyed by request fingerprint.
    ///
    /// A second caller for the same key awaits this task instead of starting
    /// a new one. The task is removed when it completes.
    private var inFlight: [WaveformCacheKey: Task<WaveformData, Never>] = [:]

    // MARK: WaveformGenerationService

    func generateWaveform(
        for source: WaveformSource,
        resolution: Int
    ) async -> WaveformData {
        guard resolution > 0 else { return .empty }

        // Build a value-type cache key from the source. Equality on this key
        // is what determines cache hits — two requests with the same URL,
        // trim, and resolution share an entry, even if the AudioSample
        // instances differ.
        let key = WaveformCacheKey(source: source, resolution: resolution)

        // Cache hit — return the stored waveform directly.
        if let cached = cache[key] {
            return cached
        }

        // In-flight hit — another caller is already decoding this exact
        // request. Await their task instead of starting a parallel decode.
        if let pending = inFlight[key] {
            return await pending.value
        }

        // Cache miss and no in-flight task. Start a new decode.
        //
        // The Task is detached from the actor's execution context so the
        // expensive decode runs on the cooperative thread pool, not by
        // serializing the actor on its own work. Other callers can still
        // enter the actor (to register interest, look up unrelated keys)
        // while the decode proceeds.
        let task = Task<WaveformData, Never>.detached(priority: .userInitiated) {
            Self.decodeAndReduce(key: key)
        }

        inFlight[key] = task
        let result = await task.value

        // Promote to the completed cache and clear the in-flight slot.
        // This re-enters the actor's isolation domain after the await, so
        // the dictionary mutations are serialized.
        cache[key] = result
        inFlight[key] = nil

        return result
    }

    // MARK: Decode

    /// Performs the actual audio file decode and amplitude reduction.
    ///
    /// `static` so it cannot accidentally touch actor-isolated state. It is
    /// the only place in the cache that opens an `AVAudioFile`, and it
    /// operates entirely on stack-local buffers.
    ///
    /// The output always contains exactly `key.resolution` points.
    /// In the unlikely case when the  trimmed region
    /// contains fewer frames than the requested resolution,
    /// the leading `actualFrames` points hold one peak each and the trailing
    /// points remain zero — a "front-dump" layout where content fills the
    /// beginning and the tail is silence. This is visually legible (the
    /// viewer can see at a glance that the sample is short) and avoids the
    /// sparse comb pattern that floor-based bucketing would otherwise
    /// produce. See the resolution contract on `WaveformCache`.
    private static func decodeAndReduce(key: WaveformCacheKey) -> WaveformData {
        let resolution = key.resolution
        let emptyResult = WaveformData(points: [Float](repeating: 0, count: resolution))

        guard let file = try? AVAudioFile(forReading: key.url) else {
            return emptyResult
        }

        let totalFrames = AVAudioFrameCount(file.length)
        guard totalFrames > 0 else {
            return emptyResult
        }

        // Resolve the trim window from ratios to frame positions.
        let startFrame = AVAudioFramePosition(
            (Double(totalFrames) * key.startTimeRatio).rounded()
        )
        let endFrame = AVAudioFramePosition(
            (Double(totalFrames) * key.endTimeRatio).rounded()
        )
        let frameCount = AVAudioFrameCount(max(0, endFrame - startFrame))
        guard frameCount > 0 else { //should have been taken care of by Editable, but defensively placed
            return emptyResult
        }

        let format = file.processingFormat
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: frameCount
        ) else {
            return emptyResult
        }

        do {
            file.framePosition = startFrame
            try file.read(into: buffer, frameCount: frameCount)
        } catch {
            return emptyResult
        }

        let actualFrames = Int(buffer.frameLength)
        guard actualFrames > 0,
              let channelData = buffer.floatChannelData
        else {
            return emptyResult
        }

        // Reduce to peak buckets, front-dumped.
        //
        // `bucketsWithContent` is the number of output points that actually
        // receive audio. When the sample is long enough to fill every bucket
        // (the normal case), this equals `resolution` and `framesPerBucket`
        // is ≥ 1. When the sample is too short, `bucketsWithContent` drops to
        // `actualFrames`, each bucket holds exactly one frame, and the
        // remaining `resolution - actualFrames` points stay zero at the end
        // of the output.
        //
        // Peak reduction (rather than RMS) preserves transients, which
        // matters for percussive content where users want to see attack
        // envelopes.
        let channelCount = Int(format.channelCount)
        let bucketsWithContent = min(resolution, actualFrames)
        let framesPerBucket = Double(actualFrames) / Double(bucketsWithContent)

        var points = [Float](repeating: 0, count: resolution)

        for bucket in 0..<bucketsWithContent {
            let bucketStart = Int((Double(bucket) * framesPerBucket).rounded(.down))
            let bucketEnd = Int((Double(bucket + 1) * framesPerBucket).rounded(.down))
            let clampedEnd = min(max(bucketEnd, bucketStart + 1), actualFrames)

            var peak: Float = 0
            for frame in bucketStart..<clampedEnd {
                // Mix down to mono before peak detection: matches what the
                // user sees in the UI (one waveform per sample, not per
                // channel) and is the standard choice for thumbnail display.
                var summed: Float = 0
                for channel in 0..<channelCount {
                    summed += channelData[channel][frame]
                }
                let mono = summed / Float(channelCount) //average across both channels
                let absValue = Swift.abs(mono)
                if absValue > peak {
                    peak = absValue
                }
            }
            points[bucket] = peak
        }

        // Normalize to [0, 1] against the global peak so quiet samples are
        // still visible. If the trimmed region is pure silence, points stays
        // zero, which is the correct visual representation.
        if let maxPeak = points.max(), maxPeak > 0 {
            for i in 0..<points.count {
                points[i] /= maxPeak
            }
        }

        return WaveformData(points: points)
    }

    // MARK: Maintenance

    /// Removes all cached waveforms and cancels any in-flight decodes.
    func clear() {
        cache.removeAll()
        for (_, task) in inFlight {
            task.cancel()
        }
        inFlight.removeAll()
    }

    /// Removes cached entries for a specific URL.
    ///
    /// Call this when a sample file is deleted or replaced on disk so that
    /// stale waveforms don't linger across all trim/resolution combinations.
    func evict(url: URL) {
        cache = cache.filter { $0.key.url != url }
        for (key, task) in inFlight where key.url == url {
            task.cancel()
            inFlight[key] = nil
        }
    }
}
