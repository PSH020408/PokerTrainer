//
//  ThreePlayerCampaignTests.swift
//  PokerTrainerCoreTests
//
//  Created by PARK, SEHO on 9/26/26.
//

import XCTest
@testable import PokerTrainerCore

final class ThreePlayerCampaignTests: XCTestCase {
    func testBothOpponentsCanBeDefeatedThroughLevelFour() throws {
        var campaign = ThreePlayerCampaign()

        for level in 1...ThreePlayerCampaign.maximumLevel {
            let game = try playerWinsAgainstBothOpponents()
            let event = campaign.recordCompletedHand(game)
            XCTAssertEqual(campaign.level, level)
            XCTAssertTrue(campaign.isLevelCleared)

            if level < ThreePlayerCampaign.maximumLevel {
                XCTAssertEqual(event, .levelCleared(level + 1))
                campaign.advanceLevel()
                XCTAssertEqual(campaign.level, level + 1)
                XCTAssertTrue(campaign.defeatedOpponents.isEmpty)
            } else {
                XCTAssertEqual(event, .championshipWon)
                XCTAssertTrue(campaign.won)
                campaign.advanceLevel()
                XCTAssertEqual(campaign.level, 4)
            }
            XCTAssertTrue(campaign.isValid)
        }
    }

    func testAnOpponentWinningDoesNotCountAsPlayerDefeat() throws {
        var game = ThreePlayerGameEngine(
            playerStack: 1_000, opponentOneStack: 20, opponentTwoStack: 20
        )
        try game.startHand()
        try game.perform(.fold, by: .player)
        try game.perform(.fold, by: .opponentOne)

        var campaign = ThreePlayerCampaign()
        XCTAssertEqual(campaign.recordCompletedHand(game), .none)
        XCTAssertTrue(campaign.defeatedOpponents.isEmpty)
    }

    func testOpponentCanEliminateAnotherAfterPlayerFolds() throws {
        var game = ThreePlayerGameEngine(
            playerStack: 1_000,
            opponentOneStack: 20,
            opponentTwoStack: 1_000
        )
        let openingCards = [
            Card(suit: .clubs, rank: 2), Card(suit: .spades, rank: 14),
            Card(suit: .clubs, rank: 5), Card(suit: .diamonds, rank: 3),
            Card(suit: .hearts, rank: 14), Card(suit: .clubs, rank: 6),
            Card(suit: .diamonds, rank: 13), Card(suit: .spades, rank: 11),
            Card(suit: .hearts, rank: 9), Card(suit: .clubs, rank: 8),
            Card(suit: .diamonds, rank: 4)
        ]
        let deck = Deck(drawOrder: openingCards + Deck.standardCards.filter {
            !openingCards.contains($0)
        })
        try game.startHand(using: deck)
        try game.perform(.fold, by: .player)
        try game.perform(.allIn, by: .opponentOne)
        try game.perform(.check, by: .opponentTwo)

        XCTAssertTrue(game.isHandComplete)
        XCTAssertEqual(game.state(for: .opponentOne).stack, 0)
        XCTAssertGreaterThan(game.state(for: .player).stack, 0)
        var campaign = ThreePlayerCampaign()
        XCTAssertEqual(campaign.recordCompletedHand(game), .opponentDefeated(.opponentOne))
        XCTAssertEqual(campaign.defeatedOpponents, [.opponentOne])
    }

    func testBlindsKeepAcceleratingUntilTheSixtiethHand() throws {
        var campaign = ThreePlayerCampaign()
        XCTAssertEqual(campaign.blindMultiplier, 1)

        for hand in 1...62 {
            var game = ThreePlayerGameEngine()
            try game.startHand()
            while !game.isHandComplete {
                let actor = try XCTUnwrap(game.currentActor)
                try game.perform(.fold, by: actor)
            }
            _ = campaign.recordCompletedHand(game)
            if hand == 12 { XCTAssertEqual(campaign.blindMultiplier, 2) }
            if hand == 24 { XCTAssertEqual(campaign.blindMultiplier, 4) }
            if hand == 36 { XCTAssertEqual(campaign.blindMultiplier, 8) }
            if hand == 48 { XCTAssertEqual(campaign.blindMultiplier, 16) }
            if hand == 60 { XCTAssertEqual(campaign.blindMultiplier, 32) }
        }

        XCTAssertEqual(campaign.handsCompletedAtLevel, 62)
        XCTAssertEqual(campaign.blindMultiplier, 32)
        XCTAssertEqual(ThreePlayerCampaign(level: 4, handsCompletedAtLevel: 60)
            .blindMultiplier, 256)
        XCTAssertTrue(campaign.isValid)
    }

    private func playerWinsAgainstBothOpponents() throws -> ThreePlayerGameEngine {
        let openingCards = [
            Card(suit: .clubs, rank: 2),
            Card(suit: .clubs, rank: 3),
            Card(suit: .spades, rank: 14),
            Card(suit: .diamonds, rank: 7),
            Card(suit: .diamonds, rank: 8),
            Card(suit: .hearts, rank: 14),
            Card(suit: .clubs, rank: 4),
            Card(suit: .diamonds, rank: 5),
            Card(suit: .hearts, rank: 9),
            Card(suit: .clubs, rank: 11),
            Card(suit: .spades, rank: 13)
        ]
        let deck = Deck(drawOrder: openingCards + Deck.standardCards.filter {
            !openingCards.contains($0)
        })

        var game = ThreePlayerGameEngine(
            playerStack: 1_000, opponentOneStack: 20, opponentTwoStack: 20
        )
        try game.startHand(using: deck)
        try game.perform(.allIn, by: .player)
        try game.perform(.call, by: .opponentOne)

        XCTAssertTrue(game.isHandComplete)
        XCTAssertEqual(game.state(for: .opponentOne).stack, 0)
        XCTAssertEqual(game.state(for: .opponentTwo).stack, 0)
        XCTAssertGreaterThan(game.handOutcome?.winnings[.player, default: 0] ?? 0, 0)
        return game
    }
}
