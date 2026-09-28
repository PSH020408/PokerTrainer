//
//  HandResultSummaryTests.swift
//  PokerTrainerCoreTests
//
//  Created by PARK, SEHO on 9/28/26.
//

import XCTest
@testable import PokerTrainerCore

final class HandResultSummaryTests: XCTestCase {
    func testHeadsUpFoldNeverPretendsToRevealWinningCards() throws {
        var game = HeadsUpGameEngine()
        try game.startHand()
        XCTAssertEqual(game.currentActor, .player)
        try game.perform(.fold, by: .player)

        let result = try XCTUnwrap(HandResultSummary.headsUp(game))
        XCTAssertEqual(result.title, "OPPONENT WINS THE POT")
        XCTAssertTrue(result.details.contains { $0.contains("hidden cards stay private") })
        XCTAssertFalse(result.details.contains { $0.contains("Winning hand:") })
        // The unmatched half of the big blind is returned, not awarded.
        XCTAssertEqual(result.awards, [PotAward(seat: .opponentOne, chips: 20)])
    }

    func testHeadsUpShowdownNamesWinningAndPlayerHands() throws {
        var game = HeadsUpGameEngine()
        let opening = [card(.spades, 14), card(.spades, 13),
                       card(.hearts, 14), card(.hearts, 13)] + safeBoard()
        try game.startHand(using: fullDeck(opening))
        var actions = 0
        while let actor = game.currentActor, actions < 20 {
            let action: PokerAction = actor == .player && game.canRaise(seat: actor)
                ? .allIn : game.amountToCall(for: actor) > 0 ? .call : .check
            try game.perform(action, by: actor)
            actions += 1
        }

        let result = try XCTUnwrap(HandResultSummary.headsUp(game))
        XCTAssertEqual(result.title, "YOU WIN THE POT")
        XCTAssertTrue(result.details.contains("Winning hand: One Pair"))
        XCTAssertTrue(result.details.contains("Your hand: One Pair"))
        XCTAssertEqual(result.awards.first?.chips, 2_000)
    }

    func testThreePlayerWinnerAndWinningRankAreExplained() throws {
        var game = ThreePlayerGameEngine()
        let opening = [card(.spades, 13), card(.spades, 12), card(.spades, 14),
                       card(.hearts, 13), card(.hearts, 12), card(.hearts, 14)] + safeBoard()
        try game.startHand(using: fullDeck(opening))
        var actions = 0
        while let actor = game.currentActor, actions < 25 {
            let action: PokerAction = actor == .player && game.canRaise(seat: actor)
                ? .allIn : game.amountToCall(for: actor) > 0 ? .call : .check
            try game.perform(action, by: actor)
            actions += 1
        }

        let result = try XCTUnwrap(HandResultSummary.threePlayer(game))
        XCTAssertEqual(result.title, "YOU WIN THE POT")
        XCTAssertTrue(result.details.contains("You +3000 · One Pair"))
        XCTAssertEqual(result.awards, [PotAward(seat: .player, chips: 3_000)])
    }

    func testFoldedPlayerIsNotPresentedAsEligibleAfterOthersShowdown() throws {
        var game = ThreePlayerGameEngine()
        try game.startHand()
        XCTAssertEqual(game.currentActor, .player)
        try game.perform(.fold, by: .player)
        var actions = 0
        while let actor = game.currentActor, actions < 30 {
            try game.perform(game.amountToCall(for: actor) > 0 ? .call : .check, by: actor)
            actions += 1
        }

        let result = try XCTUnwrap(HandResultSummary.threePlayer(game))
        XCTAssertTrue(game.state(for: .player).isFolded)
        XCTAssertTrue(result.details.contains("You folded and were not eligible for the pot"))
        XCTAssertFalse(result.awards.contains { $0.seat == .player })
    }

    private func card(_ suit: Suit, _ rank: Int) -> Card {
        Card(suit: suit, rank: rank)
    }

    private func safeBoard() -> [Card] {
        [card(.clubs, 2), card(.diamonds, 3), card(.hearts, 5),
         card(.clubs, 7), card(.diamonds, 9)]
    }

    private func fullDeck(_ opening: [Card]) -> Deck {
        Deck(drawOrder: opening + Deck.standardCards.filter { !opening.contains($0) })
    }
}
