# AudioSample & AudioSampleRepository — Developer Guide

This guide explains how to work with `AudioSample` and `AudioSampleRepository` in MetroJuicePaak. If you're touching anything that records, plays, edits, displays, or manages samples, read this first.

## TL;DR

- **Never construct an `AudioSample` directly.** The repository is the only thing that calls `AudioSample.init`. You go through `repository.addSample(url:)`.
- **Never store `AudioSample` as a concrete type.** Always store it as one of the narrow protocol views (`PlayableAudioSample`, `EditableAudioSample`, `WaveformSource`, etc.).
- **Refer to samples by `ObjectIdentifier`** when passing references between ViewModels. Ask the repository for the narrow view you need at the point of use.
- **The repository is the single source of truth.** All ViewModels share the same instance, injected at construction time.

## The mental model

`AudioSample` is a reference-typed domain model representing one recorded clip. It deliberately exposes its capabilities through several narrow protocols rather than letting consumers see the whole class. This is interface segregation: the part of your code that *plays* a sample has no business *editing* it, and the type system enforces that.

`AudioSampleRepository` is the canonical owner of every sample in the current session. It hands out narrow views of samples to whoever asks, enforces collection-wide invariants (like name uniqueness), and is itself accessed through segregated protocols so that ViewModels only see the slice of repository functionality they actually need.

The pattern, in one sentence: **the repository owns concrete samples; everyone else holds narrow protocol views, looked up by ID.**

## The narrow protocols on AudioSample

Each protocol exposes one capability. Pick the narrowest one that does what you need.

| Protocol | Use when you need to... | Used by |
|---|---|---|
| `PlayableAudioSample` | Play the sample (read URL, volume, pan, trim ratios) | Audio engine, sampler pads, sequencer |
| `NamedAudioSample` | Display the human-readable name | UI labels, lists |
| `EditableAudioSample` | Modify trim markers | Waveform editor |
| `EffectableAudioSample` | Add or modify the DSP effect chain | Effect rack UI |
| `WaveformSource` | Render a waveform or thumbnail | Pad thumbnails, sequencer mini-views, waveform editor |

You can compose these with `&`. For example, a sampler pad ViewModel that displays a name and plays the sample takes `PlayableAudioSample & NamedAudioSample`.

## The narrow protocols on AudioSampleRepository

Same idea, applied to the repository itself.

| Protocol | Use when you need to... | Methods |
|---|---|---|
| `ReadableAudioSampleRepository` | Look up samples for playback or display | `allSamples`, `getPlayableSample(for:)`, `getNamedSample(for:)` |
| `WritableAudioSampleRepository` | Add, remove, or rename samples | `addSample(url:)`, `removeSample(id:)`, `renameSample(id:to:)` |
| `EditableAudioSampleRepository` | Get a sample's editable view | `getEditableSample(for:)` |
| `EffectableAudioSampleRepository` | Get a sample's effectable view | `getEffectableSample(for:)` |
| `WaveformSourceAudioSampleRepository` | Get a sample's waveform source | `getWaveformSource(for:)` |

A ViewModel typically depends on one or two of these. The waveform editor takes `EditableAudioSampleRepository & WaveformSourceAudioSampleRepository`. The recorder takes `WritableAudioSampleRepository`. The sampler browser takes `ReadableAudioSampleRepository`.

## Common workflows

### Adding a new sample (recording finished)

The recording service finishes a take and produces a URL. The ViewModel that owns the recorder hands the URL to the repository (feel free to change your recordingDidFinish method signature as long as you use addSample the right way):

```swift
class SamplerViewModel {
    private let repository: WritableAudioSampleRepository

    func recordingDidFinish(url: URL) {
        let id = repository.addSample(url: url)
        assignToCurrentPad(id)
    }
}
```

`addSample` always succeeds and always assigns an auto-generated "Untitled N" name. If the user wants a custom name at the moment of recording, call `renameSample` immediately after (feel free to change your recordingDidFinish method signature as long as you use renameSample the right way):

```swift
func recordingDidFinish(url: URL, userSuppliedName: String?) throws {
    let id = repository.addSample(url: url)
    if let name = userSuppliedName {
        try repository.renameSample(id: id, to: name)
    }
    assignToCurrentPad(id)
}
```

### Playing a sample on a pad

A pad ViewModel needs to play a sample and display its name. It depends on the read-only repository protocol, looks up the sample by ID, and stores the narrow view (Hi Vince this is just a recommendation, let me know if you need clarification):

```swift
class PadViewModel {
    private let repository: ReadableAudioSampleRepository
    private let sampleId: ObjectIdentifier
    private let sample: PlayableAudioSample & NamedAudioSample

    init?(sampleId: ObjectIdentifier, repository: ReadableAudioSampleRepository) {
        guard let sample = repository.getNamedSample(for: sampleId) else { return nil }
        self.sampleId = sampleId
        self.repository = repository
        self.sample = sample
    }
}
```

The pad cannot mutate trim, effects, or anything else, because it never holds a reference typed as anything richer than `PlayableAudioSample & NamedAudioSample`.

### Editing a sample's trim

The waveform editor takes the sample ID and the editing-capable repository protocol, and pulls an `EditableAudioSample` view at construction time:

```swift
class WaveformEditorViewModel {
    private let editable: EditableAudioSample
    private let waveform: WaveformSource

    init?(sampleId: ObjectIdentifier,
          repository: EditableAudioSampleRepository & WaveformSourceAudioSampleRepository) {
        guard let editable = repository.getEditableSample(for: sampleId),
              let waveform = repository.getWaveformSource(for: sampleId) else { return nil }
        self.editable = editable
        self.waveform = waveform
    }

    func updateStartTrim(to ratio: Double) throws {
        try editable.setStartTimeRatio(ratio)
    }
}
```

Because `AudioSample` is `@Observable`, every other view that holds a reference to the same underlying sample (via *any* protocol) automatically re-renders when trim ratios change. You do not need to manually notify anyone.

### Renaming a sample

Renaming is a *repository operation*, not a sample operation, because uniqueness is a collection-level invariant. UI surfaces that allow renaming take `WritableAudioSampleRepository`:

```swift
class RepositoryBrowserViewModel {
    private let repository: ReadableAudioSampleRepository & WritableAudioSampleRepository

    func renameRow(id: ObjectIdentifier, to newName: String) {
        do {
            try repository.renameSample(id: id, to: newName)
        } catch WritableAudioSampleRepositoryError.nameConflict(let name) {
            showAlert("'\(name)' is already taken.")
        } catch {
            showAlert("Could not rename sample.")
        }
    }
}
```

Both the waveform editor and the repository browser can offer a rename affordance — they both call the same repository method, so validation only lives in one place.

### Removing a sample

Removal is idempotent and never throws:

```swift
repository.removeSample(id: someId)
```

The sample is gone from the pool. Any ViewModel still holding a narrow view of it will continue to function (the underlying object stays alive while any reference exists), but it can no longer be looked up. **Removing from the repository does not delete the file on disk** — file cleanup is a separate concern handled elsewhere.

## Things to *not* do

### Don't construct AudioSample yourself

```swift
// ❌ Wrong
let sample = AudioSample(url: url, name: "kick")
```

The repository is the only place that should call `AudioSample.init`. If you find yourself wanting to construct one outside the repository, ask why — usually it's because you're writing test code, in which case use a mock conforming to the relevant protocol. If you guys piss me off and I catch someone doing this, I'll make it nigh-impossible for anyone to instantiate AudioSample.

### Don't store concrete AudioSample references

```swift
// ❌ Wrong
class PadViewModel {
    private var sample: AudioSample
}

// ✅ Right
class PadViewModel {
    private var sample: PlayableAudioSample & NamedAudioSample
}
```

Storing the concrete type defeats the entire point of the protocol segregation. Even if you only ever read from it, the next person to touch the file might add a mutation, and there's nothing stopping them.

### Don't downcast to AudioSample

```swift
// ❌ Wrong
if let concrete = playable as? AudioSample {
    concrete.startTimeRatio = 0.5
}
```

This is a deliberate bypass of the architecture. The code review should reject it.

### Don't pass AudioSample references between ViewModels

```swift
// ❌ Wrong
samplerVM.handOffSampleToEditor(self.currentSample)

// ✅ Right
samplerVM.handOffSampleToEditor(ObjectIdentifier(self.currentSample))
// ...and the editor looks up its own narrow view from the repository
```

ViewModels exchange IDs, not references. Each ViewModel asks the repository for the slice of the sample it needs. This is what keeps ViewModels decoupled from each other.

### Don't store name as a separate cache

```swift
// ❌ Wrong
class PadViewModel {
    private let sample: PlayableAudioSample
    private var cachedName: String  // will go stale on rename
}
```

`AudioSample` is `@Observable`. If you read `name` through `NamedAudioSample` inside a SwiftUI view body, the view will automatically re-render when the name changes. Caching it manually creates a parallel source of truth and goes stale.

## Why it's designed this way

### Why narrow protocols on the sample?

Interface segregation. If a layer of the codebase only needs to play a sample, it should not have the *ability* to edit it, even if it would never use that ability. Narrow protocols make accidental mutation a compile error rather than a code-review concern. They also document intent: a function that takes `EditableAudioSample` is signaling exactly what it does.

### Why narrow protocols on the repository?

Same principle, applied one layer up. A ViewModel that only browses samples should not be able to delete them. By depending on `ReadableAudioSampleRepository` rather than the concrete repository, the type system enforces that.

This also makes ViewModels easier to test. A mock conforming to `ReadableAudioSampleRepository` only needs to implement three methods, not the entire repository surface.

### Why ObjectIdentifier as the key?

Because identity must be independent of any mutable display state. Names change (rename), file URLs theoretically might change (re-recording, file relocation), but the in-memory identity of an `AudioSample` instance is stable for its lifetime. Keying by `ObjectIdentifier` means the lookup map never needs to be rebuilt when other state changes.

If we ever need persistent identity across app launches, we'll add a `UUID` to `AudioSample`. `ObjectIdentifier` is for in-memory use only.

### Why is the repository the only constructor?

Three reasons:

1. **Naming policy enforcement.** Every sample passes through one creation site, so "Untitled N" auto-naming and uniqueness checks happen by construction, not by convention.
2. **Reference discipline.** If anyone outside could construct an `AudioSample`, they could keep a concrete reference and bypass the protocol-based access control. Routing all construction through the repository means no concrete reference ever escapes.
3. **Single point of evolution.** When sample construction grows new requirements (initial trim, initial effects, duration caching), there's exactly one place to update.

### Why is renaming a repository operation, not a sample operation?

Because uniqueness is a property of the *collection*, not the individual sample. A sample on its own has no way to validate "is this name already taken" — only the repository can answer that. The general principle: **mutation methods belong at the layer that holds enough context to validate the mutation**. Self-contained invariants (like trim ratios being in `[0, 1]`) live on the model. Collection-wide invariants live on the collection's owner.

## Quick reference

```swift
// Add (always auto-named)
let id = repository.addSample(url: someUrl)

// Look up — pick the protocol that matches what you need
let playable: PlayableAudioSample? = repository.getPlayableSample(for: id)
let named: (PlayableAudioSample & NamedAudioSample)? = repository.getNamedSample(for: id)
let editable: EditableAudioSample? = repository.getEditableSample(for: id)
let effectable: EffectableAudioSample? = repository.getEffectableSample(for: id)
let waveform: WaveformSource? = repository.getWaveformSource(for: id)

// All samples for browsing
let everything: [PlayableAudioSample & NamedAudioSample] = repository.allSamples

// Mutate (only through the repository)
try repository.renameSample(id: id, to: "kick")
repository.removeSample(id: id)
```

## Questions?

If you find yourself wanting to do something this guide says not to, ask Noah before working around it. The constraints exist for reasons, and most of the time there's a clean way to do what you want within them. If there isn't, that's a real architectural conversation worth having — message Noah or he will find you and kill you.
