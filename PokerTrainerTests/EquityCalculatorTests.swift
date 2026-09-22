//
//  EquityCalculatorTests.swift
//  PokerTrainerCoreTests
//
//  Created by PARK, SEHO on 9/6/26.
//

import XCTest
@testable import PokerTrainerCore

final class EquityCalculatorTests: XCTestCase {
    func testUniversalBoardTieCountsAsHalfEquityHeadsUp() {
        let playerHand = [
            Card(suit: .clubs, rank: 2),
            Card(suit: .diamonds, rank: 3)
        ]
        let royalFlushBoard = [
            Card(suit: .spades, rank: 10),
            Card(suit: .spades, rank: 11),
            Card(suit: .spades, rank: 12),
            Card(suit: .spades, rank: 13),
            Card(suit: .spades, rank: 14)
        ]

        let equity = EquityCalculator.calculateEquity(
            playerHand: playerHand,
            communityCards: royalFlushBoard,
            activePlayersCount: 2,
            simulations: 100
        )

        XCTAssertEqual(equity, 50.0, accuracy: 0.0001)
    }

    func testDuplicateKnownCardInputIsRejected() {
        let repeatedCard = Card(suit: .spades, rank: 14)

        let equity = EquityCalculator.calculateEquity(
            playerHand: [repeatedCard, repeatedCard],
            communityCards: [],
            activePlayersCount: 2,
            simulations: 100
        )

        XCTAssertEqual(equity, 0.0)
    }

    func testThreeWayUniversalTieCountsAsOneThirdEquity() {
        let playerHand = [
            Card(suit: .clubs, rank: 2),
            Card(suit: .diamonds, rank: 3)
        ]
        let royalFlushBoard = [
            Card(suit: .spades, rank: 10),
            Card(suit: .spades, rank: 11),
            Card(suit: .spades, rank: 12),
            Card(suit: .spades, rank: 13),
            Card(suit: .spades, rank: 14)
        ]

        let equity = EquityCalculator.calculateEquity(
            playerHand: playerHand,
            communityCards: royalFlushBoard,
            activePlayersCount: 3,
            simulations: 100
        )

        XCTAssertEqual(equity, 100.0 / 3.0, accuracy: 0.0001)
    }
}
