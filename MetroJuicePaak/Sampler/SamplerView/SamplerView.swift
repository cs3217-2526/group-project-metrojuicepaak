import SwiftUI

/// The main visual interface for the MetroJuicePaak drum machine.
///
/// `SamplerView` is a purely declarative, state-driven UI component. It adheres strictly
/// to Clean Architecture by delegating all hardware interaction, file management, and
/// state mutation to the injected `SamplerViewModel` (the Orchestrator).
///
struct SamplerView: View {
    
    // MARK: - Dependencies
    
    /// The central orchestrator that drives the logic, state, and audio engine interactions for this view.
    /// Marked as `@Bindable` so its properties (like `isEditMode`) can be directly tied to SwiftUI controls.
    @Bindable var orchestrator: SamplerViewModel
    
    // MARK: - Layout Configuration
    
    /// The layout definition for the 4x4 drum pad grid.
    /// Configured to evenly distribute four flexible columns with 12pt spacing.
    let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 20) {
            
            // MARK: - Top Control Section
            // Displays global session states like recording indicators and the Edit Mode toggle.
            VStack {
                Text("Session Controls")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 20) {
                    // Conditionally renders a high-visibility warning when the microphone is active.
                    if orchestrator.isRecordingPadIndex != nil {
                        Text("🎙️ Recording...")
                            .foregroundStyle(.red)
                            .font(.headline)
                    }
                    
                    Spacer()
                    
                    // Two-way binding to the Orchestrator's global Edit Mode state.
                    Toggle("Edit Mode", isOn: $orchestrator.isEditMode)
                        .toggleStyle(.button)
                        .tint(.orange)
                }
                .padding(.horizontal)
            }
            .frame(height: 60)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(12)
            
            // MARK: - 4x4 Sampler Grid
            // Iterates over physical slots 0-15, requesting a specific local ViewModel for each.
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(0..<16, id: \.self) { index in
                    
                    // Ask the factory for the local data (returns nil if the pad is empty)
                    let padVM = orchestrator.getViewModel(for: index)
                    
                    SamplerPadButton(
                        padIndex: index,
                        orchestrator: orchestrator,
                        localViewModel: padVM,
                        uiElements: SamplerPadButtonUIElements()
                    )
                    // Visual feedback: Dim empty pads when in Edit Mode so the user knows they can't be edited.
                    .opacity(orchestrator.isEditMode && padVM == nil ? 0.5 : 1.0)
                    // Visual feedback: Highlight assigned pads with an orange stroke to indicate editability.
                    .overlay(
                        orchestrator.isEditMode && padVM != nil
                        ? RoundedRectangle(cornerRadius: 12).stroke(Color.orange, lineWidth: 3)
                        : nil
                    )
                }
            }
            .padding()
            
            Spacer()
        }
        .padding()
        .navigationTitle("MetroJuicePaak")
        .navigationBarTitleDisplayMode(.inline)
        
        // MARK: - Sheet Navigation
        // Reacts to state changes in the Orchestrator to present the appropriate modal interface.
        
        // 1. Waveform Editor Modal
        .sheet(item: $orchestrator.sampleIDToEdit) { context in
            SamplerEditorContainer(orchestrator: orchestrator, sampleID: context.id)
        }
        
        // 2. Sample Picker Modal
        .sheet(item: $orchestrator.padIndexAwaitingAssignment) { context in
            SamplePickerView(repository: orchestrator.repository) { selectedNode in
                orchestrator.assignSample(selectedNode, toPad: context.id)
                orchestrator.padIndexAwaitingAssignment = nil
            }
        }
    }
}
