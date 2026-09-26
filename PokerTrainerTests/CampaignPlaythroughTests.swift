//
//  CampaignPlaythroughTests.swift
//  PokerTrainerCoreTests
//
//  Created by PARK, SEHO on 9/26/26.
//

import XCTest
@testable import PokerTrainerCore

// Deterministic full campaigns supplement, but do not replace, random UI play.
final class CampaignPlaythroughTests: XCTestCase {
    func testHeadsUpCanWinEveryLevelWithoutLosingChips() throws {
        var game = HeadsUpGameEngine()

        for level in 1...4 {
            try game.startHand(using: headsUpWinningDeck(dealer: level.isMultiple(of: 2)
                ? .opponent : .player))
            let startingChips = game.totalChipsAtHandStart

            while let actor = game.currentActor {
                if actor == .player {
                    try game.perform(game.amountToCall(for: actor) > 0 ? .call : .allIn,
                        by: actor)
                } else {
                    try game.perform(game.amountToCall(for: actor) > 0 ? .call : .allIn,
                        by: actor)
                }
                XCTAssertEqual(game.totalChipCount, startingChips)
                XCTAssertTrue(game.isValidForRestoration())
            }

            XCTAssertEqual(game.handOutcome?.winner, .player)
            XCTAssertEqual(game.opponentStack, 0)
            XCTAssertEqual(game.handNumber, level)

            if level < 4 {
                try game.replaceStacks(
                    player: game.playerStack,
                    opponent: 1_000 * (level + 1)
                )
            }
        }
    }

    func testThreePlayerCanWinEveryLevelAndChampionship() throws {
        var game = ThreePlayerGameEngine()
        var campaign = ThreePlayerCampaign()

        for level in 1...4 {
            try game.startHand(using: threePlayerWinningDeck(dealer: game.handNumber == 0
                ? .player : nextSeat(after: game.dealer)))
            let startingChips = game.totalChipsAtHandStart
            var actions = 0

            while let actor = game.currentActor, actions < 20 {
                let action: PokerAction
                if actor == .player && game.canRaise(seat: actor) {
                    action = .allIn
                } else {
                    action = game.amountToCall(for: actor) > 0 ? .call : .check
                }
                try game.perform(action, by: actor)
                XCTAssertEqual(game.totalChipCount, startingChips)
                XCTAssertTrue(game.isValidForRestoration())
                actions += 1
            }

            XCTAssertTrue(game.isHandComplete)
            XCTAssertLessThan(actions, 20)
            XCTAssertEqual(game.state(for: .opponentOne).stack, 0)
            XCTAssertEqual(game.state(for: .opponentTwo).stack, 0)
            XCTAssertEqual(campaign.recordCompletedHand(game), level == 4
                ? .championshipWon : .levelCleared(level + 1))

            if level < 4 {
                campaign.advanceLevel()
                try game.replaceStacks(
                    player: game.state(for: .player).stack,
                    opponentOne: 1_000 * (level + 1),
                    opponentTwo: 1_000 * (level + 1)
                )
            }
        }

        XCTAssertTrue(campaign.won)
        XCTAssertEqual(campaign.level, 4)
    }

    private func headsUpWinningDeck(dealer: PokerSeat) -> Deck {
        let player = [Card(suit: .spades, rank: 14), Card(suit: .hearts, rank: 14)]
        let opponent = [Card(suit: .spades, rank: 13), Card(suit: .hearts, rank: 13)]
        let board = safeBoard()
        let order = dealer == .player
            ? [player[0], opponent[0], player[1], opponent[1]]
            : [opponent[0], player[0], opponent[1], player[1]]
        return completeDeck(opening: order + board)
    }

    private func threePlayerWinningDeck(dealer: TableSeat) -> Deck {
        let hands: [TableSeat: [Card]] = [
            .player: [Card(suit: .spades, rank: 14), Card(suit: .hearts, rank: 14)],
            .opponentOne: [Card(suit: .spades, rank: 13), Card(suit: .hearts, rank: 13)],
            .opponentTwo: [Card(suit: .spades, rank: 12), Card(suit: .hearts, rank: 12)]
        ]
        let order: [TableSeat]
        switch dealer {
        case .player: order = [.opponentOne, .opponentTwo, .player]
        case .opponentOne: order = [.opponentTwo, .player, .opponentOne]
        case .opponentTwo: order = [.player, .opponentOne, .opponentTwo]
        }
        let opening = (0..<2).flatMap { cardIndex in
            order.map { hands[$0]![cardIndex] }
        }
        return completeDeck(opening: opening + safeBoard())
    }

    private func safeBoard() -> [Card] {
        [
            Card(suit: .clubs, rank: 2), Card(suit: .diamonds, rank: 3),
            Card(suit: .hearts, rank: 5), Card(suit: .clubs, rank: 7),
            Card(suit: .diamonds, rank: 9)
        ]
    }

    private func completeDeck(opening: [Card]) -> Deck {
        Deck(drawOrder: opening + Deck.standardCards.filter { !opening.contains($0) })
    }

    private func nextSeat(after seat: TableSeat) -> TableSeat {
        let all = TableSeat.allCases
        return all[(seat.rawValue + 1) % all.count]
    }
}
