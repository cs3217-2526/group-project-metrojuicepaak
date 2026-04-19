//
//  UndoRedoManager.swift
//  MetroJuicePaak
//
//  Created by Edwin Wong on 27/03/2026.
//

class UndoRedoManager {
    private var undoStack: [Command] = []
    private var redoStack: [Command] = []
    
    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }
    
    func execute(_ command: Command) {
        command.execute()
        undoStack.append(command)
        redoStack.removeAll() // Clear redo stack when a new action is performed
    }
    
    func undo() {
        guard let command = undoStack.popLast() else { return }
        command.undo()
        redoStack.append(command)
    }
    
    func redo() {
        guard let command = redoStack.popLast() else { return }
        command.execute()
        undoStack.append(command)
    }
}
