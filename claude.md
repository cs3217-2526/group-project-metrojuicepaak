# Claude AI Assistant Guidelines for MetroJuicePaak

**Last Updated:** March 22, 2026  
**Project:** MetroJuicePaak  
**Architecture:** MVVM with Service Layer (See ARCHITECTURE.md)

---

## 🎯 Core Principles

### 1. **Identity and Type Selection**

#### **Use Value Types by Default (Structs)**
- Prefer `struct` for data models unless identity semantics are required
- Structs are safer, thread-safe by default, and encourage immutability

#### **Use Reference Types (Classes) When:**
- **Shared mutable state** is needed across multiple owners
- **Lifecycle management** matters (e.g., need `deinit`)
- **Identity semantics** are meaningful (two instances with same data are *not* equivalent)

#### **Identification Strategy:**
- **Persistent models** (saved to disk): Use `UUID` or stable integer IDs
  - ✅ `UUID` is `Codable`, stable across launches, globally unique
  - ✅ Integer IDs work for ordered collections
- **Transient references** (in-memory only): Can use `ObjectIdentifier` for classes
  - ⚠️ `ObjectIdentifier` is NOT `Codable` and changes between launches
  - Only use for runtime-only identity checks

**Example:**
```swift
// ✅ GOOD: Persistent model with UUID
struct AudioSample: Codable {
    let id: UUID
    let url: URL
    let duration: TimeInterval
}

// ✅ GOOD: Reference type when identity matters
class SamplerPad: Codable {
    let id: Int  // Stable, codable ID
    var sample: AudioSample?
    // ... mutable state shared across views
}

// ✅ GOOD: Transient reference comparison
func isSamePadInstance(_ a: SamplerPad, _ b: SamplerPad) -> Bool {
    ObjectIdentifier(a) == ObjectIdentifier(b)
}
```

---

### 2. **Decoupling and Organization**

#### **Separation of Concerns**
- **Models** must be framework-agnostic (no SwiftUI, UIKit dependencies)
- **ViewModels** contain business logic, no direct UI code
- **Services** abstract external dependencies (audio, network, persistence)
- **Views** are thin, delegate logic to ViewModels

#### **File Organization**
- One primary type per file (exceptions: small helper types)
- Group related files in folders:
  - `Models/` - Pure data structures
  - `ViewModels/` - Business logic
  - `Services/` - External integrations
  - `Views/SwiftUI/` - SwiftUI views
  - `Views/UIKit/` - UIKit views (if needed)
  - `Extensions/` - Type extensions
  - `Utilities/` - Helpers and utilities

#### **Example from Project:**
```
✅ SamplerPad and AudioSample moved from SamplerView to separate model files
✅ PadColor enum in SamplerPadColors.swift with conditional SwiftUI/UIKit extensions
```

#### **When Creating New Types:**
1. Ask: "Does this belong in an existing file or need its own?"
2. Consider: "Is this a model, view, viewmodel, or service?"
3. Place in appropriate folder
4. Inform user of file creation/organization decisions

---

### 3. **Open-Closed Principle (Pragmatic Application)**

#### **Core Tenet:**
Software should be **open for extension** but **closed for modification**.

#### **Application:**
- Use protocols, enums with associated values, and composition over inheritance
- Before implementing extensibility, **ask the user** about anticipated extension points
- Avoid premature abstraction (YAGNI: You Aren't Gonna Need It)

#### **Process:**
1. When writing new types, **identify potential extension axes**:
   - "This `AudioService` could be extended with different audio engines (AVFoundation, AudioKit, etc.)"
   - "The `PadColor` enum is closed to new colors at compile time but open via raw values"
2. **Ask user**: "I see potential extension points along [X, Y, Z]. Which should we design for?"
3. **Wait for confirmation** before adding protocols, abstract base classes, or dependency injection
4. Document decisions in code comments

#### **Example:**
```swift
// ❓ Before refactoring, ask:
// "Should AudioService support multiple audio engines? 
//  If so, I'll create a protocol. If not, a concrete class is simpler."

// ✅ If yes:
protocol AudioServiceProtocol {
    func play(sample: AudioSample) async throws
}

class AVFoundationAudioService: AudioServiceProtocol { /* ... */ }
class AudioKitAudioService: AudioServiceProtocol { /* ... */ }

// ✅ If no:
class AudioService {
    func play(sample: AudioSample) async throws { /* ... */ }
}
```

---

### 4. **DRY Principle (Don't Repeat Yourself)**

#### **Core Tenet:**
Avoid code duplication, but balance with coupling concerns.

#### **Process:**
1. **Identify duplication** in code reviews or during implementation
2. **Evaluate abstraction cost**:
   - Will abstraction introduce tight coupling?
   - Is the duplication truly the *same concept* or coincidentally similar?
   - Will the abstraction be harder to understand than duplication?
3. **Inform user before refactoring**:
   - "I notice [X] is duplicated in [Y] and [Z]. I can extract it to [proposed location] without introducing coupling. Should I proceed?"
4. **Wait for approval** before refactoring

#### **Exceptions (Don't Abstract):**
- Code that's coincidentally similar but serves different purposes
- Abstractions that would introduce dependencies between unrelated modules
- Very small snippets (2-3 lines) where abstraction adds cognitive overhead

#### **Example:**
```swift
// ❌ DON'T abstract if concepts diverge:
// Color conversion logic in PadColor vs. Theme color management
// (Both deal with colors but serve different purposes)

// ✅ DO abstract if truly shared:
// Date formatting used across multiple ViewModels
extension Date {
    var displayString: String {
        // Shared formatting logic
    }
}
```

---

## 🔧 Project-Specific Guidelines

### **Framework-Agnostic Models**
- Models live in `Models/` folder
- Use `import Foundation` only (no SwiftUI/UIKit)
- Color/UI properties should be enums with extensions:

```swift
// ✅ In Models/PadColor.swift
enum PadColor: String, Codable {
    case blue, red, green
}

// ✅ In Extensions/PadColor+SwiftUI.swift
#if canImport(SwiftUI)
import SwiftUI
extension PadColor {
    var swiftUIColor: Color { /* ... */ }
}
#endif
```

### **Async/Await Preferred**
- Use Swift Concurrency for asynchronous operations
- Avoid Dispatch or Combine unless already heavily used in codebase

### **Testing Mindset**
- Services should be protocol-based to enable mocking
- ViewModels should accept injected dependencies

---

## 📋 Checklist Before Making Changes

When proposing code changes, Claude should:

- [ ] Identify if new types are models/views/viewmodels/services
- [ ] Check if new types should be in separate files
- [ ] Consider if extension points need discussion (Open-Closed)
- [ ] Look for duplication and propose abstractions (DRY)
- [ ] Ensure models have no UI framework dependencies
- [ ] Use appropriate identity strategy (UUID vs. ObjectIdentifier)
- [ ] **Ask user for confirmation** before significant refactoring

---

## 🗣️ Communication Protocol

### **When Uncertain:**
- Ask clarifying questions about future extension needs
- Propose multiple solutions with tradeoffs
- Default to simpler solutions unless complexity is justified

### **When Proposing Refactors:**
- Explain *why* (which principle is violated)
- Explain *how* (what changes are needed)
- Explain *impact* (breaking changes, test updates, etc.)
- Wait for approval before implementing

---

## 📚 Reference Documents

- **ARCHITECTURE.md** - Full architecture documentation
- **SamplerPadColors.swift** - Example of framework-agnostic enum with conditional extensions
- **SamplerPad.swift** - Example of using stable Int IDs for class identity
- **AudioSample.swift** - Example of struct-based model

---

## ✅ Summary

1. **Identity**: Use structs by default. For classes, use `UUID`/`Int` for persistence, `ObjectIdentifier` only for transient checks.
2. **Decoupling**: Separate models from UI, organize files logically, ask before creating new files.
3. **Open-Closed**: Ask user about extension axes before adding abstraction layers.
4. **DRY**: Propose abstractions but evaluate coupling cost, wait for approval.

**Guiding Philosophy:** Pragmatic over dogmatic. Simple over clever. Ask over assume.
