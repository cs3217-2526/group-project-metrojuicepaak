//
//  TempFileStore.swift
//  MetroJuicePaak
//
//  Created by Noah Ang Shi Hern on 23/3/26.
//

import Foundation

protocol TempFileStore {
    func makeURL(filename: String, extension ext: String) -> URL
    func clearAll() throws
}

struct AudioTempFileStore: TempFileStore {
    private let directory: URL

    init() {
        directory = FileManager.default
            .temporaryDirectory
            .appendingPathComponent("recordings", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
    }

    func makeURL(filename: String, extension ext: String) -> URL {
        directory.appendingPathComponent(filename).appendingPathExtension(ext)
    }

    func clearAll() throws {
        try FileManager.default.removeItem(at: directory)
    }
}
