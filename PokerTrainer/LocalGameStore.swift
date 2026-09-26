//
//  LocalGameStore.swift
//  PokerTrainer
//
//  Created by PARK, SEHO on 9/26/26.
//

import Foundation

nonisolated enum PracticeMode: String, Codable, Sendable {
    case headsUp
    case threePlayer
}

nonisolated struct HeadsUpSession: Codable, Sendable {
    let game: HeadsUpGameEngine
    let opponentLevel: Int
    let campaignWon: Bool
    let gameMessage: String

    var isValid: Bool {
        game.isValidForRestoration()
            && (1...4).contains(opponentLevel)
            && (!campaignWon || (opponentLevel == 4
                && game.opponentStack == 0 && game.isHandComplete))
    }
}

nonisolated struct ThreePlayerSession: Codable, Sendable {
    let game: ThreePlayerGameEngine
    let gameMessage: String

    var isValid: Bool {
        game.isValidForRestoration()
    }
}

nonisolated enum LocalSaveError: Error, Equatable, LocalizedError {
    case invalidSnapshot
    case unsupportedVersion

    var errorDescription: String? {
        switch self {
        case .invalidSnapshot:
            return "The saved game is incomplete or damaged. Start a new game to replace it."
        case .unsupportedVersion:
            return "This saved game was created by an incompatible app version."
        }
    }
}

// Each table has its own atomic, versioned save in the app's local container.
nonisolated struct LocalGameStore: Sendable {
    static let schemaVersion = 1
    static let shared = LocalGameStore()

    let directory: URL

    init(directory: URL? = nil) {
        let supportDirectory = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        self.directory = directory ?? supportDirectory.appendingPathComponent(
            "PokerTrainer", isDirectory: true
        )
    }

    func url(for mode: PracticeMode) -> URL {
        let filename = mode == .headsUp ? "heads-up.json" : "three-player.json"
        return directory.appendingPathComponent(filename)
    }

    func saveHeadsUp(_ session: HeadsUpSession) throws {
        guard session.isValid else { throw LocalSaveError.invalidSnapshot }
        try write(session, for: .headsUp)
    }

    func loadHeadsUp() throws -> HeadsUpSession? {
        guard let session: HeadsUpSession = try read(for: .headsUp) else { return nil }
        guard session.isValid else { throw LocalSaveError.invalidSnapshot }
        return session
    }

    func saveThreePlayer(_ session: ThreePlayerSession) throws {
        guard session.isValid else { throw LocalSaveError.invalidSnapshot }
        try write(session, for: .threePlayer)
    }

    func loadThreePlayer() throws -> ThreePlayerSession? {
        guard let session: ThreePlayerSession = try read(for: .threePlayer) else { return nil }
        guard session.isValid else { throw LocalSaveError.invalidSnapshot }
        return session
    }

    private func write<Value: Codable & Sendable>(
        _ session: Value,
        for mode: PracticeMode
    ) throws {
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let envelope = SaveEnvelope(version: Self.schemaVersion, session: session)
        let data = try JSONEncoder().encode(envelope)
        try data.write(to: url(for: mode), options: .atomic)
    }

    private func read<Value: Codable & Sendable>(
        for mode: PracticeMode
    ) throws -> Value? {
        let saveURL = url(for: mode)
        guard FileManager.default.fileExists(atPath: saveURL.path) else { return nil }

        let data = try Data(contentsOf: saveURL)
        let version = try JSONDecoder().decode(VersionHeader.self, from: data).version
        guard version == Self.schemaVersion else {
            throw LocalSaveError.unsupportedVersion
        }
        return try JSONDecoder().decode(SaveEnvelope<Value>.self, from: data).session
    }
}

nonisolated private struct VersionHeader: Decodable {
    let version: Int
}

nonisolated private struct SaveEnvelope<Value: Codable & Sendable>: Codable, Sendable {
    let version: Int
    let session: Value
}
