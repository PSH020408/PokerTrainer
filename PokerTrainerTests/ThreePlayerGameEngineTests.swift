//
//  ThreePlayerGameEngineTests.swift
//  PokerTrainerCoreTests
//
//  Created by PARK, SEHO on 9/26/26.
//

import XCTest
@testable import PokerTrainerCore

final class ThreePlayerGameEngineTests: XCTestCase {
    func testPlayerFoldWinMessageUsesCorrectGrammar() throws {
        var game = ThreePlayerGameEngine(firstDealer: .opponentOne)
        try game.startHand()
        try game.perform(.fold, by: .opponentOne)
        try game.perform(.fold, by: .opponentTwo)

        XCTAssertTrue(game.isHandComplete)
        XCTAssertTrue(game.lastMessage.hasPrefix("You win "))
    }

    func testUncalledAllInIsRefundedBeforeThreePlayerFoldPot() throws {
        var game = ThreePlayerGameEngine()
        try game.startHand()
        try game.perform(.allIn, by: .player)
        try game.perform(.fold, by: .opponentOne)
        try game.perform(.fold, by: .opponentTwo)

        let outcome = try XCTUnwrap(game.handOutcome)
        XCTAssertEqual(outcome.reason, .fold)
        XCTAssertEqual(outcome.refunds[.player], 980)
        XCTAssertEqual(outcome.pots.reduce(0) { $0 + $1.amount }, 50)
        XCTAssertEqual(outcome.winnings[.player], 50)
        XCTAssertEqual(game.state(for: .player).stack, 1_030)
        XCTAssertEqual(game.state(for: .opponentOne).stack, 990)
        XCTAssertEqual(game.state(for: .opponentTwo).stack, 980)
        XCTAssertEqual(game.totalChipCount, 3_000)
    }

    func testThreePlayerPositionsAndPreFlopOrder() throws {
        var game = ThreePlayerGameEngine(firstDealer: .player)

        try game.startHand()

        XCTAssertEqual(game.dealer, .player)
        XCTAssertEqual(game.smallBlindSeat, .opponentOne)
        XCTAssertEqual(game.bigBlindSeat, .opponentTwo)
        XCTAssertEqual(game.currentActor, .player)
        XCTAssertEqual(game.state(for: .player).currentBet, 0)
        XCTAssertEqual(game.state(for: .opponentOne).currentBet, 10)
        XCTAssertEqual(game.state(for: .opponentTwo).currentBet, 20)
        XCTAssertEqual(game.potSize, 30)
        XCTAssertEqual(game.totalChipCount, 3_000)

        let allHoleCards = TableSeat.allCases.flatMap {
            game.state(for: $0).hand
        }
        XCTAssertEqual(allHoleCards.count, 6)
        XCTAssertEqual(Set(allHoleCards).count, 6)
    }

    func testEliminatedOpponentSitsOutAndRemainingSeatsPlayHeadsUp() throws {
        var game = ThreePlayerGameEngine(
            playerStack: 1_000,
            opponentOneStack: 0,
            opponentTwoStack: 1_000,
            firstDealer: .player
        )
        try game.startHand()

        XCTAssertEqual(game.dealer, .player)
        XCTAssertEqual(game.smallBlindSeat, .player)
        XCTAssertEqual(game.bigBlindSeat, .opponentTwo)
        XCTAssertEqual(game.currentActor, .player)
        XCTAssertEqual(game.potSize, 30)
        XCTAssertTrue(game.state(for: .opponentOne).hand.isEmpty)
        XCTAssertTrue(game.state(for: .opponentOne).isFolded)
        XCTAssertEqual(game.state(for: .player).hand.count, 2)
        XCTAssertEqual(game.state(for: .opponentTwo).hand.count, 2)
        XCTAssertTrue(game.isValidForRestoration())

        try game.perform(.call, by: .player)
        try game.perform(.check, by: .opponentTwo)
        XCTAssertEqual(game.currentStreet, .flop)
        XCTAssertEqual(game.currentActor, .opponentTwo)
        XCTAssertEqual(game.totalChipCount, 2_000)
        XCTAssertTrue(game.isValidForRestoration())
    }

    func testDealerRotationSkipsAnEliminatedSeat() throws {
        var game = ThreePlayerGameEngine(firstDealer: .player)
        try game.startHand()
        try game.perform(.fold, by: .player)
        try game.perform(.fold, by: .opponentOne)

        try game.replaceStacks(player: 1_000, opponentOne: 0, opponentTwo: 1_000)
        try game.startHand()

        XCTAssertEqual(game.dealer, .opponentTwo)
        XCTAssertEqual(game.smallBlindSeat, .opponentTwo)
        XCTAssertEqual(game.bigBlindSeat, .player)
        XCTAssertEqual(game.currentActor, .opponentTwo)
        XCTAssertEqual(game.totalChipCount, 2_000)
        XCTAssertTrue(game.isValidForRestoration())
    }

    func testHeadsUpContinuationCompletesAndRotatesBlinds() throws {
        var game = ThreePlayerGameEngine(
            playerStack: 1_000,
            opponentOneStack: 0,
            opponentTwoStack: 1_000
        )
        try game.startHand()
        try game.perform(.fold, by: .player)

        XCTAssertTrue(game.isHandComplete)
        XCTAssertEqual(game.handOutcome?.reason, .fold)
        XCTAssertEqual(game.state(for: .opponentTwo).stack, 1_010)
        XCTAssertEqual(game.totalChipCount, 2_000)
        XCTAssertTrue(game.isValidForRestoration())

        try game.startHand()
        XCTAssertEqual(game.dealer, .opponentTwo)
        XCTAssertEqual(game.smallBlindSeat, .opponentTwo)
        XCTAssertEqual(game.bigBlindSeat, .player)
        XCTAssertEqual(game.currentActor, .opponentTwo)
        XCTAssertTrue(game.isValidForRestoration())
    }

    func testBlindsCanIncreaseOnlyBetweenHands() throws {
        var game = ThreePlayerGameEngine()
        try game.startHand()
        XCTAssertThrowsError(try game.setBlinds(small: 20, big: 40)) {
            XCTAssertEqual($0 as? MultiplayerRuleError, .handAlreadyInProgress)
        }
        try game.perform(.fold, by: .player)
        try game.perform(.fold, by: .opponentOne)
        try game.setBlinds(small: 20, big: 40)
        try game.startHand()

        XCTAssertEqual(game.smallBlind, 20)
        XCTAssertEqual(game.bigBlind, 40)
        XCTAssertEqual(game.state(for: .opponentTwo).currentBet, 20)
        XCTAssertEqual(game.state(for: .player).currentBet, 40)
        XCTAssertEqual(game.potSize, 60)
        XCTAssertTrue(game.isValidForRestoration())
    }

    func testCircularActionOrderAdvancesOnlyAfterAllSeatsAct() throws {
        var game = ThreePlayerGameEngine(firstDealer: .player)
        try game.startHand()

        try game.perform(.call, by: .player)
        XCTAssertEqual(game.currentActor, .opponentOne)
        XCTAssertEqual(game.currentStreet, .preFlop)

        try game.perform(.call, by: .opponentOne)
        XCTAssertEqual(game.currentActor, .opponentTwo)
        XCTAssertEqual(game.currentStreet, .preFlop)

        try game.perform(.check, by: .opponentTwo)
        XCTAssertEqual(game.currentStreet, .flop)
        XCTAssertEqual(game.currentActor, .opponentOne)
        XCTAssertEqual(game.communityCards.count, 3)

        try game.perform(.check, by: .opponentOne)
        XCTAssertEqual(game.currentActor, .opponentTwo)
        XCTAssertEqual(game.currentStreet, .flop)

        try game.perform(.check, by: .opponentTwo)
        XCTAssertEqual(game.currentActor, .player)
        XCTAssertEqual(game.currentStreet, .flop)

        try game.perform(.check, by: .player)
        XCTAssertEqual(game.currentStreet, .turn)
        XCTAssertEqual(game.currentActor, .opponentOne)
        XCTAssertEqual(game.totalChipCount, 3_000)
    }

    func testFoldedSeatIsSkippedInCircularOrder() throws {
        var game = ThreePlayerGameEngine(firstDealer: .player)
        try game.startHand()

        try game.perform(.fold, by: .player)
        XCTAssertEqual(game.currentActor, .opponentOne)

        try game.perform(.call, by: .opponentOne)
        XCTAssertEqual(game.currentActor, .opponentTwo)

        try game.perform(.check, by: .opponentTwo)

        XCTAssertEqual(game.currentStreet, .flop)
        XCTAssertEqual(game.currentActor, .opponentOne)
        XCTAssertTrue(game.state(for: .player).isFolded)
        XCTAssertEqual(game.totalChipCount, 3_000)
    }

    func testDealerRotatesAcrossCompletedHands() throws {
        var game = ThreePlayerGameEngine(firstDealer: .player)
        try game.startHand()

        try game.perform(.fold, by: .player)
        try game.perform(.fold, by: .opponentOne)
        XCTAssertTrue(game.isHandComplete)

        try game.startHand()

        XCTAssertEqual(game.dealer, .opponentOne)
        XCTAssertEqual(game.smallBlindSeat, .opponentTwo)
        XCTAssertEqual(game.bigBlindSeat, .player)
        XCTAssertEqual(game.currentActor, .opponentOne)
        XCTAssertEqual(game.totalChipCount, 3_000)
    }

    func testMainAndSidePotsUseOnlyEligibleContributionLevels() throws {
        var game = ThreePlayerGameEngine(
            playerStack: 100,
            opponentOneStack: 60,
            opponentTwoStack: 200,
            firstDealer: .player
        )
        try game.startHand(using: Deck(drawOrder: rankedDeck()))

        try game.perform(.allIn, by: .player)
        try game.perform(.allIn, by: .opponentOne)
        try game.perform(.call, by: .opponentTwo)

        XCTAssertTrue(game.isHandComplete)
        XCTAssertEqual(game.handOutcome?.reason, .showdown)
        XCTAssertEqual(
            game.handOutcome?.pots,
            [
                SidePot(
                    amount: 180,
                    eligibleSeats: [.player, .opponentOne, .opponentTwo]
                ),
                SidePot(
                    amount: 80,
                    eligibleSeats: [.player, .opponentTwo]
                )
            ]
        )
        XCTAssertEqual(game.handOutcome?.winnings[.opponentOne], 180)
        XCTAssertEqual(game.handOutcome?.winnings[.player], 80)
        XCTAssertNil(game.handOutcome?.winnings[.opponentTwo])
        XCTAssertEqual(game.state(for: .player).stack, 80)
        XCTAssertEqual(game.state(for: .opponentOne).stack, 180)
        XCTAssertEqual(game.state(for: .opponentTwo).stack, 100)
        XCTAssertEqual(game.totalChipCount, 360)
    }

    func testSingleContributorTopLayerIsRefunded() throws {
        var game = ThreePlayerGameEngine(
            playerStack: 200,
            opponentOneStack: 50,
            opponentTwoStack: 50,
            firstDealer: .player
        )
        try game.startHand(using: Deck(drawOrder: rankedDeck()))

        try game.perform(.allIn, by: .player)
        try game.perform(.allIn, by: .opponentOne)
        try game.perform(.allIn, by: .opponentTwo)

        XCTAssertTrue(game.isHandComplete)
        XCTAssertEqual(
            game.handOutcome?.pots,
            [
                SidePot(
                    amount: 150,
                    eligibleSeats: [.player, .opponentOne, .opponentTwo]
                )
            ]
        )
        XCTAssertEqual(game.handOutcome?.refunds[.player], 150)
        XCTAssertEqual(game.handOutcome?.winnings[.opponentOne], 150)
        XCTAssertEqual(game.state(for: .player).stack, 150)
        XCTAssertEqual(game.state(for: .opponentOne).stack, 150)
        XCTAssertEqual(game.state(for: .opponentTwo).stack, 0)
        XCTAssertEqual(game.totalChipCount, 300)
    }

    func testFoldedBestHandCannotWinAnyPot() throws {
        var game = ThreePlayerGameEngine(
            playerStack: 100,
            opponentOneStack: 100,
            opponentTwoStack: 100,
            firstDealer: .player
        )
        try game.startHand(using: Deck(drawOrder: foldedBestHandDeck()))

        try game.perform(.raise(amount: 40), by: .player)
        try game.perform(.call, by: .opponentOne)
        try game.perform(.fold, by: .opponentTwo)

        try checkThroughStreet(&game, seats: [.opponentOne, .player])
        try checkThroughStreet(&game, seats: [.opponentOne, .player])
        try checkThroughStreet(&game, seats: [.opponentOne, .player])

        XCTAssertTrue(game.isHandComplete)
        XCTAssertTrue(game.state(for: .opponentTwo).isFolded)
        XCTAssertNil(game.handOutcome?.winnings[.opponentTwo])
        XCTAssertEqual(game.handOutcome?.winnings[.opponentOne], 140)
        XCTAssertEqual(game.state(for: .player).stack, 40)
        XCTAssertEqual(game.state(for: .opponentOne).stack, 180)
        XCTAssertEqual(game.state(for: .opponentTwo).stack, 80)
        XCTAssertEqual(game.totalChipCount, 300)
    }

    func testShortAllInDoesNotReopenRaisingForPreviousAggressor() throws {
        var game = ThreePlayerGameEngine(
            playerStack: 100,
            opponentOneStack: 50,
            opponentTwoStack: 100,
            firstDealer: .player
        )
        try game.startHand()

        try game.perform(.raise(amount: 20), by: .player)
        try game.perform(.allIn, by: .opponentOne)
        try game.perform(.call, by: .opponentTwo)

        XCTAssertEqual(game.currentActor, .player)
        XCTAssertEqual(game.amountToCall(for: .player), 10)
        XCTAssertFalse(game.canRaise(seat: .player))
        let stackBeforeRejectedActions = game.state(for: .player).stack
        let potBeforeRejectedActions = game.potSize
        XCTAssertThrowsError(
            try game.perform(.raise(amount: 20), by: .player)
        ) { error in
            XCTAssertEqual(error as? MultiplayerRuleError, .raiseNotReopened)
        }
        XCTAssertThrowsError(
            try game.perform(.allIn, by: .player)
        ) { error in
            XCTAssertEqual(error as? MultiplayerRuleError, .raiseNotReopened)
        }
        XCTAssertEqual(game.state(for: .player).stack, stackBeforeRejectedActions)
        XCTAssertEqual(game.potSize, potBeforeRejectedActions)

        try game.perform(.call, by: .player)
        XCTAssertEqual(game.currentStreet, .flop)
        XCTAssertEqual(game.totalChipCount, 250)
    }

    func testChipConservationAcrossScriptedThreePlayerHands() throws {
        var game = ThreePlayerGameEngine(
            playerStack: 300,
            opponentOneStack: 300,
            opponentTwoStack: 300,
            firstDealer: .player
        )

        for handIndex in 0..<60 {
            if TableSeat.allCases.contains(where: { game.state(for: $0).stack == 0 }) {
                try game.replaceStacks(
                    player: 300,
                    opponentOne: 300,
                    opponentTwo: 300
                )
            }

            try game.startHand(using: Deck(drawOrder: rotatedDeck(by: handIndex)))
            let expectedTotal = game.totalChipsAtHandStart
            var actionCount = 0

            while !game.isHandComplete {
                guard let actor = game.currentActor else {
                    XCTFail("An active three-player hand must always have an actor.")
                    return
                }

                let callAmount = game.amountToCall(for: actor)
                let action: PokerAction
                if actionCount > 30 {
                    action = .fold
                } else if game.canRaise(seat: actor),
                          (handIndex + actionCount).isMultiple(of: 7) {
                    action = .allIn
                } else if callAmount > 0 {
                    action = .call
                } else {
                    action = .check
                }

                try game.perform(action, by: actor)
                actionCount += 1

                XCTAssertEqual(game.totalChipCount, expectedTotal)
                for seat in TableSeat.allCases {
                    XCTAssertGreaterThanOrEqual(game.state(for: seat).stack, 0)
                }
                XCTAssertGreaterThanOrEqual(game.potSize, 0)
            }

            XCTAssertLessThanOrEqual(actionCount, 31)
            XCTAssertEqual(game.totalChipCount, expectedTotal)
        }
    }

    private func checkThroughStreet(
        _ game: inout ThreePlayerGameEngine,
        seats: [TableSeat]
    ) throws {
        for seat in seats {
            try game.perform(.check, by: seat)
        }
    }

    private func rankedDeck() -> [Card] {
        [
            Card(suit: .spades, rank: 14),
            Card(suit: .clubs, rank: 3),
            Card(suit: .spades, rank: 13),
            Card(suit: .hearts, rank: 14),
            Card(suit: .diamonds, rank: 4),
            Card(suit: .hearts, rank: 13),
            Card(suit: .diamonds, rank: 2),
            Card(suit: .clubs, rank: 7),
            Card(suit: .spades, rank: 9),
            Card(suit: .diamonds, rank: 11),
            Card(suit: .hearts, rank: 12)
        ]
    }

    private func foldedBestHandDeck() -> [Card] {
        [
            Card(suit: .spades, rank: 13),
            Card(suit: .spades, rank: 14),
            Card(suit: .clubs, rank: 3),
            Card(suit: .hearts, rank: 13),
            Card(suit: .hearts, rank: 14),
            Card(suit: .diamonds, rank: 4),
            Card(suit: .diamonds, rank: 2),
            Card(suit: .clubs, rank: 7),
            Card(suit: .spades, rank: 9),
            Card(suit: .diamonds, rank: 11),
            Card(suit: .hearts, rank: 12)
        ]
    }

    private func rotatedDeck(by offset: Int) -> [Card] {
        let cards = Deck.standardCards
        let splitIndex = offset % cards.count
        return Array(cards[splitIndex...]) + Array(cards[..<splitIndex])
    }
}
