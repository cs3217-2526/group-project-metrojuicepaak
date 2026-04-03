# Audio Service Protocol Architecture

## Overview

The audio system is split into clear protocol-based responsibilities, allowing for:
- ✅ Easy testing with mock implementations
- ✅ Clear separation of concerns
- ✅ Flexible service composition
- ✅ Type-safe API boundaries

---

## Protocol Hierarchy

```
AudioServiceProtocol (Combined)
    ├─ AudioPlaybackService
    ├─ AudioRecordingService
    └─ AudioConfigurationService

WaveformGenerationService (Separate)
```

---

## 1. AudioPlaybackService

**Responsibility:** Loading, playing, and stopping audio samples

### Core Methods

```swift
// Loading lifecycle
func load(_ sample: AudioSample) async throws
func unload(_ sample: AudioSample) async
func isLoaded(_ sample: AudioSample) -> Bool

// Playback control
func play(_ sample: AudioSample, volume: Float, pan: Float) async
func stop(_ sample: AudioSample) async
func stopAll() async
func isPlaying(_ sample: AudioSample) -> Bool
```

### Usage Example

```swift
// In SamplerViewModel:
func assignSampleToPad(_ sampleID: UUID, padIndex: Int) async throws {
    guard let sample = repositoryVM.repository.getSample(by: sampleID) else { return }
    
    // 1. Load into AudioService
    try await audioService.load(sample)
    
    // 2. Update repository
    var repo = repositoryVM.repository
    repo.assignSampleToPad(sampleID, padIndex: padIndex)
    repositoryVM.repository = repo
}

func playPad(_ padIndex: Int) async {
    guard let sample = getSample(for: padIndex) else { return }
    await audioService.play(sample, volume: 0.8, pan: 0.0)
}

func clearPad(_ padIndex: Int) async {
    guard let sample = getSample(for: padIndex) else { return }
    
    // Update repository
    var repo = repositoryVM.repository
    repo.clearPad(padIndex)
    repositoryVM.repository = repo
    
    // Unload if not used elsewhere
    if !isStillInUse(sample.id) {
        await audioService.unload(sample)
    }
}
```

---

## 2. AudioRecordingService

**Responsibility:** Recording audio from device microphone

### Core Methods

```swift
func startRecording(settings: RecordingSettings?) async throws -> Bool
func stopRecording() async -> RecordingResult?

var isRecording: Bool { get }
var recordingDuration: TimeInterval { get }
```

### RecordingResult Structure

```swift
struct RecordingResult {
    let url: URL              // Absolute path (e.g., /Documents/A1B2C3D4.m4a)
    let duration: TimeInterval
    var filename: String      // Extracted filename (e.g., "A1B2C3D4.m4a")
}
```

### Usage Example

```swift
// In SamplerViewModel:
func handlePadPressed(_ padIndex: Int) async throws {
    guard !audioService.isRecording else { return }
    
    // Start recording
    let started = try await audioService.startRecording()
    if started {
        // Update UI to show recording state
    }
}

func handlePadReleased(_ padIndex: Int) async throws {
    guard let result = await audioService.stopRecording() else { return }
    
    // 1. Add to repository
    var repo = repositoryVM.repository
    let sample = repo.addSample(
        filename: result.filename,  // Just the filename, not full URL!
        duration: result.duration
    )
    repo.assignSampleToPad(sample.id, padIndex: padIndex)
    repositoryVM.repository = repo
    
    // 2. Load for playback
    try await audioService.load(sample)
    
    // 3. Generate waveform
    if let clip = repositoryVM.getClip(for: sample.id) {
        await clip.regenerateWaveform()
    }
}
```

---

## 3. AudioConfigurationService

**Responsibility:** Managing audio session and global settings

### Core Methods

```swift
func configureAudioSession() throws
func setMasterVolume(_ volume: Float)
func setDuckingEnabled(_ enabled: Bool)

var masterVolume: Float { get }
```

### Usage Example

```swift
// In App initialization:
@main
struct MetroJuicePaakApp: App {
    @State private var audioService: AudioService?
    
    var body: some Scene {
        WindowGroup {
            if let service = audioService {
                ContentView()
                    .environment(service)
            } else {
                ProgressView("Initializing Audio...")
                    .task {
                        do {
                            audioService = try await AudioService()
                        } catch {
                            print("Failed to initialize audio: \(error)")
                        }
                    }
            }
        }
    }
}

// In SettingsView:
func updateVolume(_ volume: Float) {
    audioService.setMasterVolume(volume)
}

func toggleDucking(_ enabled: Bool) {
    audioService.setDuckingEnabled(enabled)
}
```

---

## 4. WaveformGenerationService (Separate Protocol)

**Responsibility:** Generating waveform visualization data

### Core Method

```swift
func generateWaveform(
    for sample: AudioSample,
    resolution: Int,
    startRatio: Double,
    endRatio: Double
) async -> [Float]
```

### Usage Example

```swift
// In AudioClipViewModel:
@Observable
class AudioClipViewModel {
    private(set) var sample: AudioSample
    private(set) var thumbnailData: [Float] = []
    
    private let waveformService: WaveformGenerationService
    
    func regenerateWaveform() async {
        thumbnailData = await waveformService.generateWaveform(
            for: sample,
            resolution: 100,
            startRatio: sample.startTimeRatio,
            endRatio: sample.endTimeRatio
        )
    }
}
```

---

## Key Design Decisions

### 1. Why AudioSample (not URL) as Parameter?

```swift
// ✅ GOOD: AudioService works with AudioSample
func play(_ sample: AudioSample, volume: Float, pan: Float) async

// ❌ BAD: AudioService works with raw data
func play(url: URL, startRatio: Double, endRatio: Double, volume: Float) async
```

**Reason:** AudioSample encapsulates all playback information (trim points, filename, etc.). AudioService doesn't need to know about ratios—it just reads them from the sample.

### 2. Why Separate Protocols?

**Allows for flexible composition:**

```swift
// Mock for testing playback only
class MockPlaybackService: AudioPlaybackService { ... }

// Mock for testing recording only
class MockRecordingService: AudioRecordingService { ... }

// Full service in production
class AudioService: AudioServiceProtocol { ... }
```

### 3. Why async/await?

**All operations that touch file system or hardware are async:**

```swift
// ✅ Can be called from MainActor without blocking UI
await audioService.load(sample)      // File I/O
await audioService.play(sample)       // Hardware buffer scheduling
await audioService.stopRecording()    // File writing
```

---

## Complete Data Flow Example: Recording to Playback

```swift
// 1. User holds Pad 1
samplerViewModel.handlePadPressed(padIndex: 0)
    ↓
audioService.startRecording()
    → AVAudioRecorder starts
    → Writing to /Documents/A1B2C3D4.m4a

// 2. User releases Pad 1
samplerViewModel.handlePadReleased(padIndex: 0)
    ↓
let result = audioService.stopRecording()
    → Returns RecordingResult(url: /Documents/A1B2C3D4.m4a, duration: 2.3)
    ↓
repository.addSample(filename: "A1B2C3D4.m4a", duration: 2.3)
    → Creates AudioSample with auto-name "Untitled 1"
    → Stores only filename (NOT absolute URL)
    ↓
repository.assignSampleToPad(sampleID, padIndex: 0)
    → samplerPadAssignments[0] = sampleID
    ↓
audioService.load(sample)
    → Reconstructs URL: /Documents/A1B2C3D4.m4a
    → Loads into AVAudioPCMBuffer
    ↓
repositoryVM.getClip(for: sampleID).regenerateWaveform()
    → Generates thumbnail data for UI

// 3. User taps Pad 1
samplerViewModel.playPad(padIndex: 0)
    ↓
audioService.play(sample, volume: 1.0, pan: 0.0)
    → Slices buffer from sample.startTimeRatio to sample.endTimeRatio
    → Schedules buffer segment
    → Plays audio! 🎵
```

---

## Testing Strategy

### Unit Test: Playback

```swift
@Test("Load and play sample")
func testPlayback() async throws {
    let mockService = MockPlaybackService()
    let sample = AudioSample(
        filename: "test.m4a",
        duration: 1.0,
        name: "Test"
    )
    
    try await mockService.load(sample)
    #expect(mockService.isLoaded(sample))
    
    await mockService.play(sample)
    #expect(mockService.isPlaying(sample))
}
```

### Integration Test: Recording Flow

```swift
@Test("Record and save to repository")
func testRecordingFlow() async throws {
    let service = try await AudioService()
    var repository = AudioSampleRepository()
    
    // Start recording
    let started = try await service.startRecording()
    #expect(started)
    
    // Simulate recording duration
    try await Task.sleep(for: .seconds(1))
    
    // Stop recording
    guard let result = await service.stopRecording() else {
        Issue.record("Recording failed")
        return
    }
    
    // Add to repository
    let sample = repository.addSample(
        filename: result.filename,
        duration: result.duration
    )
    
    #expect(sample.name == "Untitled 1")
    #expect(sample.duration > 0)
}
```

---

## Summary: Protocol Responsibilities

| Protocol | Manages | Depends On | Used By |
|----------|---------|-----------|---------|
| `AudioPlaybackService` | Buffer loading, playback scheduling | AVAudioEngine, file system | SamplerViewModel, StepSequencerViewModel |
| `AudioRecordingService` | Microphone capture, file writing | AVAudioRecorder | SamplerViewModel |
| `AudioConfigurationService` | Audio session, global settings | AVAudioSession | App initialization, SettingsView |
| `WaveformGenerationService` | Visualization data | Audio file analysis | AudioClipViewModel |

**All protocols work with `AudioSample` struct** - the single source of truth for audio file metadata.
