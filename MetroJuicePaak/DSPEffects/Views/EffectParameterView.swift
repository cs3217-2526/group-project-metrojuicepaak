//
//  EffectParameterView.swift
//  MetroJuicePaak
//
//  Created by Noah Ang Shi Hern on 18/4/26.
//

import SwiftUI

struct EffectParameterView: View {
    let descriptor: ParameterDescriptor
    let currentValue: Float
    let onChanged: (Float) -> Void
    let onCommitted: (Float) -> Void

    /// Local drag state. While the user is actively dragging, this holds the
    /// live value the UI is showing. When nil, the view displays `currentValue`
    /// directly (which comes from the descriptor).
    @State private var liveValue: Float?

    /// What the control should display RIGHT NOW.
    /// Prefers local drag state if present, otherwise falls back to the descriptor value.
    private var displayValue: Float {
        liveValue ?? currentValue
    }

    var body: some View {
        VStack {
            Text(descriptor.displayName)
                .font(.caption)

            switch descriptor.controlHint {
            case .knob, .fader:
                Slider(
                    value: Binding(
                        get: { displayValue },
                        set: { newVal in
                            liveValue = newVal
                            onChanged(newVal)
                        }
                    ),
                    in: descriptor.minValue...descriptor.maxValue,
                    onEditingChanged: { editing in
                        if !editing {
                            // Commit the FINAL local value, not `currentValue`
                            // (which still holds the pre-drag value).
                            let final = liveValue ?? currentValue
                            onCommitted(final)
                            // Clear local state so we fall back to the descriptor.
                            liveValue = nil
                        }
                    }
                )

            case .toggle:
                Toggle("", isOn: Binding(
                    get: { displayValue > 0.5 },
                    set: { newVal in
                        let v: Float = newVal ? 1.0 : 0.0
                        onChanged(v)
                        onCommitted(v)
                    }
                ))

            case .stepped:
                Stepper(
                    value: Binding(
                        get: { Int(displayValue) },
                        set: { newVal in
                            let v = Float(newVal)
                            onChanged(v)
                            onCommitted(v)
                        }
                    ),
                    in: Int(descriptor.minValue)...Int(descriptor.maxValue)
                ) {
                    Text("\(Int(displayValue))")
                }

            case .indexed:
                Picker("", selection: Binding(
                    get: { Int(displayValue) },
                    set: { newIndex in
                        let v = Float(newIndex)
                        onChanged(v)
                        onCommitted(v)
                    }
                )) {
                    ForEach(Array((descriptor.valueLabels ?? []).enumerated()),
                            id: \.offset) { index, label in
                        Text(label).tag(index)
                    }
                }
                .pickerStyle(.segmented)
            }

            Text(formatValue(displayValue, unit: descriptor.unit))
                .font(.caption2)
        }
    }

    private func formatValue(_ value: Float, unit: ParameterUnit) -> String {
        switch unit {
        case .hertz:
            return value >= 1000
                ? String(format: "%.1f kHz", value / 1000)
                : String(format: "%.0f Hz", value)
        case .decibels:
            return String(format: "%+.1f dB", value)
        case .seconds:
            return value < 1.0
                ? String(format: "%.0f ms", value * 1000)
                : String(format: "%.2f s", value)
        case .milliseconds:
            return String(format: "%.0f ms", value)
        case .percent:
            return String(format: "%.0f%%", value * 100)
        case .ratio:
            return String(format: "%.1f:1", value)
        case .semitones:
            return String(format: "%+.0f st", value)
        case .unitless:
            return String(format: "%.2f", value)
        }
    }
}

