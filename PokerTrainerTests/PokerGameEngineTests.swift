//
//  PokerGameEngineTests.swift
//  PokerTrainerCoreTests
//
//  Created by PARK, SEHO on 9/6/26.
//

import XCTest
@testable import PokerTrainerCore

final class PokerGameEngineTests: XCTestCase {
    func testBlindsAndPreFlopActionOrder() throws {
        var game = HeadsUpGameEngine(firstDealer: .player)

        try game.startHand()

        XCTAssertEqual(game.dealer, .player)
        XCTAssertEqual(game.currentActor, .player)
        XCTAssertEqual(game.playerCurrentBet, 10)
        XCTAssertEqual(game.opponentCurrentBet, 20)
        XCTAssertEqual(game.potSize, 30)
        XCTAssertEqual(game.totalChipCount, 2_000)

        try game.perform(.call, by: .player)

        XCTAssertEqual(game.currentStreet, .preFlop)
        XCTAssertEqual(game.currentActor, .opponent)
        XCTAssertEqual(game.playerCurrentBet, 20)
        XCTAssertEqual(game.opponentCurrentBet, 20)

        try game.perform(.check, by: .opponent)

        XCTAssertEqual(game.currentStreet, .flop)
        XCTAssertEqual(game.currentActor, .opponent)
        XCTAssertEqual(game.communityCards.count, 3)
        XCTAssertEqual(game.playerCurrentBet, 0)
        XCTAssertEqual(game.opponentCurrentBet, 0)
        XCTAssertEqual(game.totalChipCount, 2_000)
    }

    func testAFirstCheckDoesNotSkipTheOtherPlayer() throws {
        var game = HeadsUpGameEngine(firstDealer: .player)
        try game.startHand()
        try game.perform(.call, by: .player)
        try game.perform(.check, by: .opponent)

        try game.perform(.check, by: .opponent)

        XCTAssertEqual(game.currentStreet, .flop)
        XCTAssertEqual(game.currentActor, .player)

        try game.perform(.check, by: .player)

        XCTAssertEqual(game.currentStreet, .turn)
        XCTAssertEqual(game.currentActor, .opponent)
        XCTAssertEqual(game.communityCards.count, 4)
        XCTAssertEqual(game.totalChipCount, 2_000)
    }

    func testEffectiveAllInStillRequiresAResponse() throws {
        var game = HeadsUpGameEngine(
            playerStack: 100,
            opponentStack: 1_000,
            firstDealer: .opponent
        )
        try game.startHand()

        try game.perform(.allIn, by: .opponent)

        XCTAssertFalse(game.isHandComplete)
        XCTAssertEqual(game.currentActor, .player)
        XCTAssertEqual(game.playerAmountToCall, 80)
        XCTAssertEqual(game.opponentStack, 900)
        XCTAssertEqual(game.totalChipCount, 1_100)

        try game.perform(.fold, by: .player)

        XCTAssertTrue(game.isHandComplete)
        XCTAssertEqual(game.handOutcome?.reason, .fold)
        XCTAssertEqual(game.totalChipCount, 1_100)
    }

    func testUnmatchedBlindChipsAreReturnedBeforeShowdown() throws {
        var game = HeadsUpGameEngine(
            playerStack: 5,
            opponentStack: 1_000,
            firstDealer: .player
        )

        try game.startHand()

        XCTAssertTrue(game.isHandComplete)
        XCTAssertEqual(game.handOutcome?.reason, .showdown)
        XCTAssertEqual(game.handOutcome?.awardedPot, 10)
        XCTAssertEqual(game.totalChipCount, 1_005)
        XCTAssertEqual(game.potSize, 0)
    }

    func testBigBlindAllInStillAllowsTheSmallBlindToRespond() throws {
        var game = HeadsUpGameEngine(
            playerStack: 1_000,
            opponentStack: 20,
            firstDealer: .player
        )

        try game.startHand()

        XCTAssertFalse(game.isHandComplete)
        XCTAssertEqual(game.currentActor, .player)
        XCTAssertEqual(game.playerAmountToCall, 10)
        XCTAssertEqual(game.opponentStack, 0)
        XCTAssertEqual(game.totalChipCount, 1_020)

        try game.perform(.call, by: .player)

        XCTAssertTrue(game.isHandComplete)
        XCTAssertEqual(game.handOutcome?.reason, .showdown)
        XCTAssertEqual(game.handOutcome?.awardedPot, 40)
        XCTAssertEqual(game.totalChipCount, 1_020)
    }

    func testShortAllInCallReturnsTheUnmatchedChips() throws {
        var game = HeadsUpGameEngine(
            playerStack: 15,
            opponentStack: 1_000,
            firstDealer: .player
        )

        try game.startHand()
        XCTAssertEqual(game.playerAmountToCall, 10)

        try game.perform(.allIn, by: .player)

        XCTAssertTrue(game.isHandComplete)
        XCTAssertEqual(game.handOutcome?.reason, .showdown)
        XCTAssertEqual(game.handOutcome?.awardedPot, 30)
        XCTAssertEqual(game.totalChipCount, 1_015)
    }

    func testFoldDoesNotRevealOpponentCards() throws {
        var game = HeadsUpGameEngine(firstDealer: .player)
        try game.startHand()

        try game.perform(.fold, by: .player)

        XCTAssertTrue(game.isHandComplete)
        XCTAssertEqual(game.handOutcome?.reason, .fold)
        XCTAssertFalse(game.shouldRevealOpponentCards)
        XCTAssertEqual(game.currentStreet, .preFlop)
        XCTAssertEqual(game.totalChipCount, 2_000)
    }

    func testIllegalCheckDoesNotMutateTheGame() throws {
        var game = HeadsUpGameEngine(firstDealer: .player)
        try game.startHand()
        let originalPot = game.potSize
        let originalPlayerStack = game.playerStack

        XCTAssertThrowsError(try game.perform(.check, by: .player)) { error in
            XCTAssertEqual(error as? GameRuleError, .cannotCheckFacingBet)
        }

        XCTAssertEqual(game.currentActor, .player)
        XCTAssertEqual(game.potSize, originalPot)
        XCTAssertEqual(game.playerStack, originalPlayerStack)
        XCTAssertEqual(game.totalChipCount, 2_000)
    }

    func testDealerAlternatesBetweenHands() throws {
        var game = HeadsUpGameEngine(firstDealer: .player)
        try game.startHand()
        XCTAssertEqual(game.dealer, .player)

        try game.perform(.fold, by: .player)
        try game.startHand()

        XCTAssertEqual(game.dealer, .opponent)
        XCTAssertEqual(game.currentActor, .opponent)
        XCTAssertEqual(game.totalChipCount, 2_000)
    }

    func testBoardRoyalFlushSplitsThePot() throws {
        let drawOrder = [
            Card(suit: .clubs, rank: 2),
            Card(suit: .diamonds, rank: 4),
            Card(suit: .clubs, rank: 3),
            Card(suit: .diamonds, rank: 5),
            Card(suit: .spades, rank: 10),
            Card(suit: .spades, rank: 11),
            Card(suit: .spades, rank: 12),
            Card(suit: .spades, rank: 13),
            Card(suit: .spades, rank: 14)
        ]
        var game = HeadsUpGameEngine(
            playerStack: 100,
            opponentStack: 100,
            firstDealer: .player
        )
        try game.startHand(using: Deck(drawOrder: drawOrder))

        try game.perform(.call, by: .player)
        try game.perform(.check, by: .opponent)
        try checkThroughStreet(&game, first: .opponent, second: .player)
        try checkThroughStreet(&game, first: .opponent, second: .player)
        try checkThroughStreet(&game, first: .opponent, second: .player)

        XCTAssertTrue(game.isHandComplete)
        XCTAssertEqual(game.handOutcome?.reason, .showdown)
        XCTAssertNil(game.handOutcome?.winner)
        XCTAssertEqual(game.handOutcome?.winningRank, .straightFlush)
        XCTAssertTrue(game.shouldRevealOpponentCards)
        XCTAssertEqual(game.playerStack, 100)
        XCTAssertEqual(game.opponentStack, 100)
        XCTAssertEqual(game.totalChipCount, 200)
    }

    func testRaiseBelowMinimumIsRejected() throws {
        var game = HeadsUpGameEngine(firstDealer: .player)
        try game.startHand()

        XCTAssertThrowsError(try game.perform(.raise(amount: 5), by: .player)) { error in
            XCTAssertEqual(error as? GameRuleError, .invalidRaise)
        }

        XCTAssertEqual(game.currentActor, .player)
        XCTAssertEqual(game.potSize, 30)
        XCTAssertEqual(game.totalChipCount, 2_000)
    }

    func testChipConservationAcrossScriptedHands() throws {
        var game = HeadsUpGameEngine(firstDealer: .player)

        for handIndex in 0..<100 {
            if game.playerStack == 0 || game.opponentStack == 0 {
                try game.replaceStacks(player: 1_000, opponent: 1_000)
            }

            try game.startHand(using: Deck(drawOrder: rotatedDeck(by: handIndex)))
            let expectedTotal = game.totalChipsAtHandStart
            var actionCount = 0

            while !game.isHandComplete {
                guard let actor = game.currentActor else {
                    XCTFail("An active hand must always have an actor.")
                    return
                }

                let callAmount = game.amountToCall(for: actor)
                let action: PokerAction
                if actionCount > 20 {
                    action = .fold
                } else if callAmount > 0 {
                    action = (handIndex + actionCount).isMultiple(of: 5) ? .allIn : .call
                } else if game.canRaise(seat: actor), (handIndex + actionCount).isMultiple(of: 4) {
                    action = .allIn
                } else {
                    action = .check
                }

                try game.perform(action, by: actor)
                actionCount += 1

                XCTAssertEqual(game.totalChipCount, expectedTotal)
                XCTAssertGreaterThanOrEqual(game.playerStack, 0)
                XCTAssertGreaterThanOrEqual(game.opponentStack, 0)
                XCTAssertGreaterThanOrEqual(game.potSize, 0)
            }

            XCTAssertLessThanOrEqual(actionCount, 21)
            XCTAssertEqual(game.totalChipCount, expectedTotal)
        }
    }

    private func checkThroughStreet(
        _ game: inout HeadsUpGameEngine,
        first: PokerSeat,
        second: PokerSeat
    ) throws {
        try game.perform(.check, by: first)
        try game.perform(.check, by: second)
    }

    private func rotatedDeck(by offset: Int) -> [Card] {
        let cards = Deck.standardCards
        let splitIndex = offset % cards.count
        return Array(cards[splitIndex...]) + Array(cards[..<splitIndex])
    }
}
