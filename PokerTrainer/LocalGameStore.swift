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
    let campaign: ThreePlayerCampaign

    init(
        game: ThreePlayerGameEngine,
        gameMessage: String,
        campaign: ThreePlayerCampaign = ThreePlayerCampaign()
    ) {
        self.game = game
        self.gameMessage = gameMessage
        self.campaign = campaign
    }

    private enum CodingKeys: String, CodingKey {
        case game, gameMessage, campaign
    }

    // Saves made before the campaign existed remain playable at level one.
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        game = try values.decode(ThreePlayerGameEngine.self, forKey: .game)
        gameMessage = try values.decode(String.self, forKey: .gameMessage)
        if let savedCampaign = try values.decodeIfPresent(
            ThreePlayerCampaign.self, forKey: .campaign
        ) {
            campaign = savedCampaign
        } else {
            var migratedCampaign = ThreePlayerCampaign()
            _ = migratedCampaign.recordCompletedHand(game)
            campaign = migratedCampaign
        }
    }

    var isValid: Bool {
        guard game.isValidForRestoration(), campaign.isValid,
              campaign.handsCompletedAtLevel <= game.handNumber,
              !campaign.won || game.isHandComplete else {
            return false
        }
        // A zero-chip opponent may still be all-in during an active hand.
        // Only seats already out, or busted at the completed hand, count here.
        if game.state(for: .player).stack > 0 {
            let eliminatedAtTable = Set(ThreePlayerCampaign.opponentSeats.filter { seat in
                let state = game.state(for: seat)
                return state.stack == 0 && (game.isHandComplete || state.hand.isEmpty)
            })
            return campaign.defeatedOpponents == eliminatedAtTable
        }
        return true
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
    static let schemaVersion = 2
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
        guard version == 1 || version == Self.schemaVersion else {
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
