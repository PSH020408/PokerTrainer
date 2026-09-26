//
//  OpponentStrategyTests.swift
//  PokerTrainerCoreTests
//
//  Created by PARK, SEHO on 9/26/26.
//

import XCTest
@testable import PokerTrainerCore

final class OpponentStrategyTests: XCTestCase {
    func testHigherLevelStopsOvercallingWeakHands() {
        var context = sampleContext(
            cards: [Card(suit: .clubs, rank: 7), Card(suit: .diamonds, rank: 2)],
            equity: 30,
            pot: 100,
            call: 60,
            level: 1
        )
        XCTAssertEqual(OpponentStrategy.decide(context), .call)

        context.level = 4
        XCTAssertEqual(OpponentStrategy.decide(context), .fold)
    }

    func testPositionChangesHighLevelPreflopDecision() {
        var context = sampleContext(
            cards: [Card(suit: .clubs, rank: 13), Card(suit: .diamonds, rank: 11)],
            equity: 62,
            pot: 40,
            call: 0,
            level: 4
        )
        context.isInPosition = true
        XCTAssertEqual(OpponentStrategy.decide(context), .raise(amount: 26))

        context.isInPosition = false
        XCTAssertEqual(OpponentStrategy.decide(context), .check)
    }

    func testWetBoardDiscouragesMarginalValueRaise() {
        var context = sampleContext(
            cards: [Card(suit: .spades, rank: 14), Card(suit: .clubs, rank: 10)],
            equity: 63,
            pot: 100,
            call: 0,
            level: 4
        )
        context.isInPosition = true
        context.communityCards = [
            Card(suit: .clubs, rank: 2),
            Card(suit: .diamonds, rank: 8),
            Card(suit: .spades, rank: 13)
        ]
        XCTAssertEqual(OpponentStrategy.boardTexture(context.communityCards), 0)
        XCTAssertEqual(OpponentStrategy.decide(context), .raise(amount: 65))

        context.communityCards = [
            Card(suit: .hearts, rank: 8),
            Card(suit: .hearts, rank: 9),
            Card(suit: .hearts, rank: 10)
        ]
        XCTAssertGreaterThanOrEqual(OpponentStrategy.boardTexture(context.communityCards), 2)
        XCTAssertEqual(OpponentStrategy.decide(context), .check)
    }

    func testShortRaiseBecomesLegalAllIn() {
        var context = sampleContext(
            cards: [Card(suit: .spades, rank: 14), Card(suit: .hearts, rank: 14)],
            equity: 95,
            pot: 80,
            call: 20,
            level: 4
        )
        context.minimumRaise = 60
        context.maximumRaise = 25
        XCTAssertEqual(OpponentStrategy.decide(context), .allIn)

        context.canRaise = false
        XCTAssertEqual(OpponentStrategy.decide(context), .call)
    }

    func testHighLevelDoesNotReRaiseMarginalEquityIntoPressure() {
        var context = sampleContext(
            cards: [Card(suit: .spades, rank: 14), Card(suit: .clubs, rank: 13)],
            equity: 70,
            pot: 100,
            call: 0,
            level: 4
        )
        context.isInPosition = true
        context.communityCards = [
            Card(suit: .clubs, rank: 2),
            Card(suit: .diamonds, rank: 8),
            Card(suit: .hearts, rank: 12)
        ]
        XCTAssertEqual(OpponentStrategy.decide(context), .raise(amount: 65))

        context.amountToCall = 100
        XCTAssertEqual(OpponentStrategy.decide(context), .call)
    }

    func testPersonalityChangesActionsWithoutChangingLevel() {
        var context = sampleContext(
            cards: [Card(suit: .spades, rank: 13), Card(suit: .clubs, rank: 11)],
            equity: 62,
            pot: 40,
            call: 0,
            level: 4
        )
        context.personality = .aggressive
        XCTAssertEqual(OpponentStrategy.decide(context), .raise(amount: 30))

        context.personality = .cautious
        XCTAssertEqual(OpponentStrategy.decide(context), .check)
    }

    func testPolicyActionsRemainLegalThroughScriptedHeadsUpHands() throws {
        for handIndex in 0..<24 {
            var game = HeadsUpGameEngine(playerStack: 300, opponentStack: 300)
            try game.startHand(using: rotatedDeck(by: handIndex))
            var actions = 0
            while let actor = game.currentActor, actions < 100 {
                let action: PokerAction
                if actor == .player {
                    action = game.amountToCall(for: .player) > 0 ? .call : .check
                } else {
                    var context = sampleContext(
                        cards: game.opponentHand,
                        equity: Double(12 + (actions * 19 + handIndex * 7) % 83),
                        pot: game.potSize,
                        call: game.amountToCall(for: .opponent),
                        level: 1 + handIndex % 4
                    )
                    context.communityCards = game.communityCards
                    context.minimumRaise = game.minimumRaiseAmount
                    context.maximumRaise = game.maximumRaiseAmount(for: .opponent)
                    context.canRaise = game.canRaise(seat: .opponent)
                    context.isInPosition = game.dealer == .opponent
                    context.randomRoll = Double(actions % 10) / 10
                    action = OpponentStrategy.decide(context)
                }
                try game.perform(action, by: actor)
                XCTAssertEqual(game.totalChipCount, 600)
                XCTAssertTrue(game.isValidForRestoration())
                actions += 1
            }
            XCTAssertTrue(game.isHandComplete)
            XCTAssertLessThan(actions, 100)
        }
    }

    func testPolicyActionsRemainLegalThroughScriptedThreePlayerHands() throws {
        for handIndex in 0..<24 {
            var game = ThreePlayerGameEngine(
                playerStack: 300, opponentOneStack: 300, opponentTwoStack: 300
            )
            try game.startHand(using: rotatedDeck(by: handIndex))
            var actions = 0
            while let actor = game.currentActor, actions < 120 {
                let action: PokerAction
                if actor == .player {
                    action = game.amountToCall(for: .player) > 0 ? .call : .check
                } else {
                    var context = sampleContext(
                        cards: game.state(for: actor).hand,
                        equity: Double(12 + (actions * 23 + handIndex * 11) % 83),
                        pot: game.potSize,
                        call: game.amountToCall(for: actor),
                        level: 1 + handIndex % 4
                    )
                    context.communityCards = game.communityCards
                    context.minimumRaise = game.minimumRaiseAmount
                    context.maximumRaise = game.maximumRaiseAmount(for: actor)
                    context.canRaise = game.canRaise(seat: actor)
                    context.isInPosition = game.dealer == actor
                    context.activePlayers = game.liveSeats.count
                    context.randomRoll = Double(actions % 10) / 10
                    action = OpponentStrategy.decide(context)
                }
                try game.perform(action, by: actor)
                XCTAssertEqual(game.totalChipCount, 900)
                XCTAssertTrue(game.isValidForRestoration())
                actions += 1
            }
            XCTAssertTrue(game.isHandComplete)
            XCTAssertLessThan(actions, 120)
        }
    }

    private func sampleContext(
        cards: [Card], equity: Double, pot: Int, call: Int, level: Int
    ) -> OpponentDecisionContext {
        OpponentDecisionContext(
            holeCards: cards,
            communityCards: [],
            equity: equity,
            potSize: pot,
            amountToCall: call,
            minimumRaise: 20,
            maximumRaise: 300,
            canRaise: true,
            isInPosition: false,
            activePlayers: 2,
            level: level,
            randomRoll: 0.5
        )
    }

    private func rotatedDeck(by offset: Int) -> Deck {
        let cards = Deck.standardCards
        let shift = offset % cards.count
        return Deck(drawOrder: Array(cards[shift...]) + Array(cards[..<shift]))
    }
}
