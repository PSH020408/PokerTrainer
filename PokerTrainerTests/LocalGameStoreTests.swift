//
//  LocalGameStoreTests.swift
//  PokerTrainerCoreTests
//
//  Created by PARK, SEHO on 9/26/26.
//

import Foundation
import XCTest
@testable import PokerTrainerCore

final class LocalGameStoreTests: XCTestCase {
    func testHeadsUpResumeKeepsTurnAndRemainingDeck() throws {
        let store = try makeStore()
        var original = HeadsUpGameEngine()
        try original.startHand(using: Deck(shuffled: false))
        try original.perform(.call, by: .player)

        try store.saveHeadsUp(HeadsUpSession(
            game: original,
            opponentLevel: 2,
            campaignWon: false,
            gameMessage: original.lastMessage
        ))

        let saved = try XCTUnwrap(store.loadHeadsUp())
        XCTAssertEqual(saved.opponentLevel, 2)
        XCTAssertEqual(saved.game.currentActor, .opponent)
        XCTAssertEqual(saved.game.playerHand, original.playerHand)
        XCTAssertEqual(saved.game.opponentHand, original.opponentHand)
        XCTAssertEqual(saved.game.playerStack, original.playerStack)
        XCTAssertEqual(saved.game.potSize, original.potSize)

        var restored = saved.game
        try original.perform(.check, by: .opponent)
        try restored.perform(.check, by: .opponent)

        XCTAssertEqual(restored.currentStreet, .flop)
        XCTAssertEqual(restored.currentActor, original.currentActor)
        XCTAssertEqual(restored.communityCards, original.communityCards)
        XCTAssertEqual(restored.totalChipCount, original.totalChipCount)
    }

    func testThreePlayerResumeKeepsTurnAndRemainingDeck() throws {
        let store = try makeStore()
        var original = ThreePlayerGameEngine()
        try original.startHand(using: Deck(shuffled: false))
        try original.perform(.call, by: .player)
        try original.perform(.call, by: .opponentOne)

        try store.saveThreePlayer(ThreePlayerSession(
            game: original,
            gameMessage: original.lastMessage
        ))

        let saved = try XCTUnwrap(store.loadThreePlayer())
        XCTAssertEqual(saved.game.currentActor, .opponentTwo)
        XCTAssertEqual(saved.game.dealer, .player)
        XCTAssertEqual(saved.game.potSize, 60)
        for seat in TableSeat.allCases {
            XCTAssertEqual(saved.game.state(for: seat), original.state(for: seat))
        }

        var restored = saved.game
        try original.perform(.check, by: .opponentTwo)
        try restored.perform(.check, by: .opponentTwo)

        XCTAssertEqual(restored.currentStreet, .flop)
        XCTAssertEqual(restored.currentActor, original.currentActor)
        XCTAssertEqual(restored.communityCards, original.communityCards)
        XCTAssertEqual(restored.totalChipCount, original.totalChipCount)
    }

    func testEliminatedOpponentStaysOutAfterSaveAndResume() throws {
        let store = try makeStore()
        var original = ThreePlayerGameEngine(
            playerStack: 1_000,
            opponentOneStack: 0,
            opponentTwoStack: 1_000
        )
        try original.startHand(using: Deck(shuffled: false))
        try original.perform(.call, by: .player)
        try store.saveThreePlayer(ThreePlayerSession(
            game: original,
            gameMessage: original.lastMessage,
            campaign: ThreePlayerCampaign(
                level: 1,
                defeatedOpponents: [.opponentOne]
            )
        ))

        let saved = try XCTUnwrap(store.loadThreePlayer())
        XCTAssertEqual(saved.campaign.defeatedOpponents, [.opponentOne])
        XCTAssertTrue(saved.game.state(for: .opponentOne).hand.isEmpty)
        XCTAssertTrue(saved.game.state(for: .opponentOne).isFolded)
        XCTAssertEqual(saved.game.currentActor, .opponentTwo)

        var restored = saved.game
        try original.perform(.check, by: .opponentTwo)
        try restored.perform(.check, by: .opponentTwo)
        XCTAssertEqual(restored.currentStreet, .flop)
        XCTAssertEqual(restored.currentActor, original.currentActor)
        XCTAssertEqual(restored.communityCards, original.communityCards)
        XCTAssertEqual(restored.totalChipCount, 2_000)
    }

    func testCompletedHandRestoresDealerRotation() throws {
        let store = try makeStore()
        var game = ThreePlayerGameEngine()
        try game.startHand()
        try game.perform(.fold, by: .player)
        try game.perform(.fold, by: .opponentOne)
        XCTAssertTrue(game.isHandComplete)

        try store.saveThreePlayer(ThreePlayerSession(
            game: game,
            gameMessage: game.lastMessage
        ))
        var restored = try XCTUnwrap(store.loadThreePlayer()).game
        XCTAssertEqual(restored.handOutcome?.reason, .fold)

        try restored.startHand()
        XCTAssertEqual(restored.dealer, .opponentOne)
        XCTAssertEqual(restored.currentActor, .opponentOne)
    }

    func testSavedModesAreIndependent() throws {
        let store = try makeStore()
        var headsUp = HeadsUpGameEngine()
        var threePlayer = ThreePlayerGameEngine()
        try headsUp.startHand()
        try threePlayer.startHand()

        try store.saveHeadsUp(HeadsUpSession(
            game: headsUp,
            opponentLevel: 1,
            campaignWon: false,
            gameMessage: headsUp.lastMessage
        ))
        try store.saveThreePlayer(ThreePlayerSession(
            game: threePlayer,
            gameMessage: threePlayer.lastMessage
        ))

        try headsUp.perform(.call, by: .player)
        try store.saveHeadsUp(HeadsUpSession(
            game: headsUp,
            opponentLevel: 1,
            campaignWon: false,
            gameMessage: headsUp.lastMessage
        ))

        XCTAssertEqual(try store.loadHeadsUp()?.game.currentActor, .opponent)
        XCTAssertEqual(try store.loadThreePlayer()?.game.currentActor, .player)
    }

    func testVersionOneThreePlayerSaveMigratesToCampaign() throws {
        let store = try makeStore()
        var game = ThreePlayerGameEngine()
        try game.startHand()
        try store.saveThreePlayer(ThreePlayerSession(
            game: game,
            gameMessage: game.lastMessage
        ))

        let saveURL = store.url(for: .threePlayer)
        let data = try Data(contentsOf: saveURL)
        var envelope = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        var session = try XCTUnwrap(envelope["session"] as? [String: Any])
        session.removeValue(forKey: "campaign")
        envelope["session"] = session
        envelope["version"] = 1
        try JSONSerialization.data(withJSONObject: envelope).write(to: saveURL)

        let migrated = try XCTUnwrap(store.loadThreePlayer())
        XCTAssertEqual(migrated.campaign.level, 1)
        XCTAssertTrue(migrated.campaign.defeatedOpponents.isEmpty)
    }

    func testEarlierCampaignSaveDefaultsBlindClockToZero() throws {
        let store = try makeStore()
        var game = ThreePlayerGameEngine()
        try game.startHand()
        try store.saveThreePlayer(ThreePlayerSession(
            game: game,
            gameMessage: game.lastMessage
        ))

        let saveURL = store.url(for: .threePlayer)
        let data = try Data(contentsOf: saveURL)
        var envelope = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        var session = try XCTUnwrap(envelope["session"] as? [String: Any])
        var campaign = try XCTUnwrap(session["campaign"] as? [String: Any])
        campaign.removeValue(forKey: "handsCompletedAtLevel")
        session["campaign"] = campaign
        envelope["session"] = session
        try JSONSerialization.data(withJSONObject: envelope).write(to: saveURL)

        let restored = try XCTUnwrap(store.loadThreePlayer())
        XCTAssertEqual(restored.campaign.handsCompletedAtLevel, 0)
        XCTAssertEqual(restored.campaign.blindMultiplier, 1)
    }

    func testCorruptAndUnsupportedSavesDoNotLoad() throws {
        let store = try makeStore()
        let saveURL = store.url(for: .headsUp)
        XCTAssertNil(try store.loadHeadsUp())

        try Data("{\"version\":99}".utf8).write(to: saveURL)
        XCTAssertThrowsError(try store.loadHeadsUp()) { error in
            XCTAssertEqual(error as? LocalSaveError, .unsupportedVersion)
        }

        try Data("not a saved game".utf8).write(to: saveURL)
        XCTAssertThrowsError(try store.loadHeadsUp())
        XCTAssertTrue(FileManager.default.fileExists(atPath: saveURL.path))

        var newGame = HeadsUpGameEngine()
        try newGame.startHand()
        try store.saveHeadsUp(HeadsUpSession(
            game: newGame,
            opponentLevel: 1,
            campaignWon: false,
            gameMessage: newGame.lastMessage
        ))
        XCTAssertEqual(try store.loadHeadsUp()?.game.handNumber, 1)
    }

    func testDamagedChipCountIsRejected() throws {
        let store = try makeStore()
        var game = HeadsUpGameEngine()
        try game.startHand()
        try store.saveHeadsUp(HeadsUpSession(
            game: game,
            opponentLevel: 1,
            campaignWon: false,
            gameMessage: game.lastMessage
        ))

        try alterSavedHeadsUpGame(in: store) { $0["playerStack"] = -100 }

        XCTAssertThrowsError(try store.loadHeadsUp()) { error in
            XCTAssertEqual(error as? LocalSaveError, .invalidSnapshot)
        }
    }

    func testDamagedTurnIsRejected() throws {
        let store = try makeStore()
        var game = HeadsUpGameEngine()
        try game.startHand()
        try store.saveHeadsUp(HeadsUpSession(
            game: game,
            opponentLevel: 1,
            campaignWon: false,
            gameMessage: game.lastMessage
        ))

        try alterSavedHeadsUpGame(in: store) { $0["currentActor"] = "opponent" }

        XCTAssertThrowsError(try store.loadHeadsUp()) { error in
            XCTAssertEqual(error as? LocalSaveError, .invalidSnapshot)
        }
    }

    func testDuplicateSavedCardIsRejected() throws {
        let store = try makeStore()
        var game = HeadsUpGameEngine()
        try game.startHand()
        try store.saveHeadsUp(HeadsUpSession(
            game: game,
            opponentLevel: 1,
            campaignWon: false,
            gameMessage: game.lastMessage
        ))

        try alterSavedHeadsUpGame(in: store) { savedGame in
            guard var playerHand = savedGame["playerHand"] as? [[String: Any]],
                  let opponentHand = savedGame["opponentHand"] as? [[String: Any]] else {
                return
            }
            playerHand[0] = opponentHand[0]
            savedGame["playerHand"] = playerHand
        }

        XCTAssertThrowsError(try store.loadHeadsUp()) { error in
            XCTAssertEqual(error as? LocalSaveError, .invalidSnapshot)
        }
    }

    private func alterSavedHeadsUpGame(
        in store: LocalGameStore,
        _ change: (inout [String: Any]) -> Void
    ) throws {
        let saveURL = store.url(for: .headsUp)
        let data = try Data(contentsOf: saveURL)
        var envelope = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        var session = try XCTUnwrap(envelope["session"] as? [String: Any])
        var savedGame = try XCTUnwrap(session["game"] as? [String: Any])
        change(&savedGame)
        session["game"] = savedGame
        envelope["session"] = session
        try JSONSerialization.data(withJSONObject: envelope).write(to: saveURL)
    }

    private func makeStore() throws -> LocalGameStore {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "PokerTrainerSaveTests-\(UUID().uuidString)", isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true
        )
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
        }
        return LocalGameStore(directory: directory)
    }
}
