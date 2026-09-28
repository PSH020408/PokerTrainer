//
//  LongSessionStabilityTests.swift
//  PokerTrainerCoreTests
//
//  Created by PARK, SEHO on 9/28/26.
//

import Foundation
import XCTest
@testable import PokerTrainerCore

// Opt-in core stress run. This checks long save/restore sequences, not phone battery or heat.
final class LongSessionStabilityTests: XCTestCase {
    func testFiveHundredHandsPerModeWithSaveAfterEveryAction() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["POKERTRAINER_STRESS"] == "1",
            "Set POKERTRAINER_STRESS=1 to run the long-session save test."
        )

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "PokerTrainer-long-session-\(UUID().uuidString)", isDirectory: true
        )
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = LocalGameStore(directory: directory)

        try exerciseHeadsUp(store: store, hands: 500)
        try exerciseThreeSeat(store: store, hands: 500)
    }

    private func exerciseHeadsUp(store: LocalGameStore, hands: Int) throws {
        var game = HeadsUpGameEngine()
        var level = 1
        var won = false
        var actions = 0

        for handIndex in 0..<hands {
            if won || game.playerStack == 0 {
                game = HeadsUpGameEngine()
                level = 1
                won = false
            } else if game.opponentStack == 0 {
                level += 1
                try game.replaceStacks(player: game.playerStack, opponent: 1_000 * level)
            }

            var generator = StressGenerator(seed: 10_000 + UInt64(handIndex))
            try game.startHand(using: Deck(
                drawOrder: Deck.standardCards.shuffled(using: &generator)
            ))
            if game.isHandComplete && game.opponentStack == 0 && level == 4 {
                won = true
            }
            let expectedChips = game.totalChipsAtHandStart
            var handActions = 0

            while let actor = game.currentActor, handActions < 100 {
                let choice = (handIndex * 17 + handActions * 13
                    + (actor == .player ? 0 : 7)) % 37
                let action = legalAction(
                    call: game.amountToCall(for: actor),
                    canRaise: game.canRaise(seat: actor),
                    minimumRaise: game.minimumRaiseAmount,
                    maximumRaise: game.maximumRaiseAmount(for: actor),
                    choice: choice
                )
                try game.perform(action, by: actor)
                if game.isHandComplete && game.opponentStack == 0 && level == 4 {
                    won = true
                }
                XCTAssertEqual(game.totalChipCount, expectedChips)
                XCTAssertTrue(game.isValidForRestoration())

                try store.saveHeadsUp(HeadsUpSession(
                    game: game, opponentLevel: level,
                    campaignWon: won, gameMessage: game.lastMessage
                ))
                let restored = try XCTUnwrap(store.loadHeadsUp())
                XCTAssertEqual(restored.game.totalChipCount, expectedChips)
                XCTAssertEqual(restored.game.currentActor, game.currentActor)
                game = restored.game
                handActions += 1
                actions += 1
            }
            XCTAssertTrue(game.isHandComplete)
            XCTAssertLessThan(handActions, 100)
        }

        print("Long-session heads-up: \(hands) hands, \(actions) actions and save/restores")
    }

    private func exerciseThreeSeat(store: LocalGameStore, hands: Int) throws {
        var game = ThreePlayerGameEngine()
        var campaign = ThreePlayerCampaign()
        var actions = 0

        for handIndex in 0..<hands {
            if campaign.won || game.state(for: .player).stack == 0 {
                game = ThreePlayerGameEngine()
                campaign = ThreePlayerCampaign()
            } else if campaign.isLevelCleared {
                campaign.advanceLevel()
                try game.replaceStacks(
                    player: game.state(for: .player).stack,
                    opponentOne: 1_000 * campaign.level,
                    opponentTwo: 1_000 * campaign.level
                )
            }

            try game.setBlinds(
                small: 10 * campaign.blindMultiplier,
                big: 20 * campaign.blindMultiplier
            )
            var generator = StressGenerator(seed: 20_000 + UInt64(handIndex))
            try game.startHand(using: Deck(
                drawOrder: Deck.standardCards.shuffled(using: &generator)
            ))
            if game.isHandComplete {
                _ = campaign.recordCompletedHand(game)
            }
            let expectedChips = game.totalChipsAtHandStart
            var handActions = 0

            while let actor = game.currentActor, handActions < 120 {
                let choice = (handIndex * 19 + handActions * 11 + actor.rawValue * 7) % 41
                let action = legalAction(
                    call: game.amountToCall(for: actor),
                    canRaise: game.canRaise(seat: actor),
                    minimumRaise: game.minimumRaiseAmount,
                    maximumRaise: game.maximumRaiseAmount(for: actor),
                    choice: choice
                )
                try game.perform(action, by: actor)
                if game.isHandComplete {
                    _ = campaign.recordCompletedHand(game)
                }
                XCTAssertEqual(game.totalChipCount, expectedChips)
                XCTAssertTrue(game.isValidForRestoration())

                try store.saveThreePlayer(ThreePlayerSession(
                    game: game, gameMessage: game.lastMessage, campaign: campaign
                ))
                let restored = try XCTUnwrap(store.loadThreePlayer())
                XCTAssertEqual(restored.game.totalChipCount, expectedChips)
                XCTAssertEqual(restored.game.currentActor, game.currentActor)
                game = restored.game
                campaign = restored.campaign
                handActions += 1
                actions += 1
            }
            XCTAssertTrue(game.isHandComplete)
            XCTAssertLessThan(handActions, 120)
        }

        print("Long-session three-seat: \(hands) hands, \(actions) actions and save/restores")
    }

    private func legalAction(
        call: Int, canRaise: Bool, minimumRaise: Int,
        maximumRaise: Int, choice: Int
    ) -> PokerAction {
        if canRaise && choice == 0 { return .allIn }
        if canRaise && choice.isMultiple(of: 11) {
            return maximumRaise <= minimumRaise
                ? .allIn : .raise(amount: minimumRaise)
        }
        if call > 0 {
            return choice.isMultiple(of: 17) ? .fold : .call
        }
        return .check
    }
}

private struct StressGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }
}
