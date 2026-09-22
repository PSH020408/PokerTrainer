//
//  EvaluatorTests.swift
//  PokerTrainerCoreTests
//
//  Created by PARK, SEHO on 9/6/26.
//

import XCTest
@testable import PokerTrainerCore

final class EvaluatorTests: XCTestCase {
    func testAceLowStraightUsesFiveAsItsHighCard() {
        let cards = [
            Card(suit: .spades, rank: 14),
            Card(suit: .hearts, rank: 2),
            Card(suit: .diamonds, rank: 3),
            Card(suit: .clubs, rank: 4),
            Card(suit: .spades, rank: 5),
            Card(suit: .hearts, rank: 9),
            Card(suit: .diamonds, rank: 13)
        ]

        let score = Evaluator.evaluate(cards: cards)

        XCTAssertEqual(score.rank, .straight)
        XCTAssertEqual(score.tieBreakers, [5])
    }

    func testBestFiveCardsSelectAFullHouseFromSevenCards() {
        let cards = [
            Card(suit: .spades, rank: 12),
            Card(suit: .hearts, rank: 12),
            Card(suit: .diamonds, rank: 12),
            Card(suit: .clubs, rank: 9),
            Card(suit: .spades, rank: 9),
            Card(suit: .hearts, rank: 4),
            Card(suit: .diamonds, rank: 2)
        ]

        let score = Evaluator.evaluate(cards: cards)

        XCTAssertEqual(score.rank, .fullHouse)
        XCTAssertEqual(score.tieBreakers, [12, 9])
    }

    func testTwoPairKickerBreaksATie() {
        let stronger = HandScore(rank: .twoPair, tieBreakers: [14, 10, 9])
        let weaker = HandScore(rank: .twoPair, tieBreakers: [14, 10, 8])

        XCTAssertGreaterThan(stronger, weaker)
    }

    func testHighCardHandKeepsAllKickers() {
        let cards = [
            Card(suit: .spades, rank: 14),
            Card(suit: .hearts, rank: 11),
            Card(suit: .diamonds, rank: 9),
            Card(suit: .clubs, rank: 7),
            Card(suit: .spades, rank: 4),
            Card(suit: .hearts, rank: 3),
            Card(suit: .diamonds, rank: 2)
        ]

        let score = Evaluator.evaluate(cards: cards)

        XCTAssertEqual(score.rank, .highCard)
        XCTAssertEqual(score.tieBreakers, [14, 11, 9, 7, 4])
    }
}
