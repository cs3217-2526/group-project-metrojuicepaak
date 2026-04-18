//
//  SampleEditorMode.swift
//  MetroJuicePaak
//
//  Created by Noah Ang Shi Hern on 18/4/26.
//


enum SampleEditorMode: String, CaseIterable, Identifiable {
    case trim = "Trim"
    case effects = "Effects"

    var id: String { rawValue }
}