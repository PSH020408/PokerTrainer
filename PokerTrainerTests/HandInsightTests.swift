//
//  HandInsightTests.swift
//  PokerTrainerCoreTests
//
//  Created by PARK, SEHO on 9/28/26.
//

import XCTest
@testable import PokerTrainerCore

final class HandInsightTests: XCTestCase {
    func testPreFlopPocketPairAndSuitedStartAreDescribedSeparately() {
        let pair = HandInsight.analyze(
            holeCards: [card(.spades, 12), card(.hearts, 12)],
            board: [], potSize: 30, amountToCall: 10, randomHandEquity: 80
        )
        XCTAssertEqual(pair.madeHand, "Pocket pair")
        XCTAssertTrue(pair.possibilities.contains { $0.contains("three of a kind") })
        XCTAssertEqual(pair.potOdds!, 25, accuracy: 0.001)

        let suited = HandInsight.analyze(
            holeCards: [card(.spades, 14), card(.spades, 9)],
            board: [], potSize: 30, amountToCall: 0, randomHandEquity: nil
        )
        XCTAssertEqual(suited.madeHand, "Ace high before the flop")
        XCTAssertTrue(suited.possibilities.contains { $0.contains("flush") })
        XCTAssertNil(suited.potOdds)
    }

    func testMadeHandAndOneCardFlushAndStraightDraws() {
        let insight = HandInsight.analyze(
            holeCards: [card(.hearts, 8), card(.hearts, 9)],
            board: [card(.hearts, 6), card(.hearts, 7), card(.clubs, 13)],
            potSize: 100, amountToCall: 20, randomHandEquity: 40
        )
        XCTAssertEqual(insight.madeHand, "High Card")
        XCTAssertTrue(insight.possibilities.contains { $0.contains("Flush draw") })
        XCTAssertTrue(insight.possibilities.contains { $0.contains("2 distinct ranks") })
    }

    func testRiverReportsFinalMadeHandWithoutFutureDraws() {
        let insight = HandInsight.analyze(
            holeCards: [card(.spades, 14), card(.diamonds, 14)],
            board: [card(.clubs, 14), card(.hearts, 2), card(.spades, 2),
                    card(.hearts, 9), card(.clubs, 10)],
            potSize: 200, amountToCall: 0, randomHandEquity: 95
        )
        XCTAssertEqual(insight.madeHand, "Full House")
        XCTAssertEqual(insight.possibilities, ["The board is complete; no more cards will be dealt."])
    }

    func testPairUpgradePathIsExplainedOnTheTurn() {
        let insight = HandInsight.analyze(
            holeCards: [card(.spades, 12), card(.hearts, 7)],
            board: [card(.clubs, 12), card(.diamonds, 4), card(.clubs, 2),
                    card(.spades, 9)],
            potSize: 100, amountToCall: 0, randomHandEquity: 65
        )
        XCTAssertEqual(insight.madeHand, "One Pair")
        XCTAssertTrue(insight.possibilities.contains { $0.contains("three of a kind") })
        XCTAssertTrue(insight.possibilities.contains { $0.contains("two pair") })
    }

    func testBoardOnlyStraightWarnsThatOpponentMayShareIt() {
        let insight = HandInsight.analyze(
            holeCards: [card(.spades, 2), card(.hearts, 14)],
            board: [card(.clubs, 5), card(.diamonds, 6), card(.spades, 7),
                    card(.hearts, 8), card(.clubs, 9)],
            potSize: 100, amountToCall: 0, randomHandEquity: 50
        )
        XCTAssertEqual(insight.madeHand, "Straight")
        XCTAssertTrue(insight.possibilities.contains { $0.contains("board plays") })
    }

    func testPoorCallPriceIsFlaggedWithoutClaimingToKnowOpponentRange() {
        let insight = HandInsight.analyze(
            holeCards: [card(.clubs, 2), card(.diamonds, 7)],
            board: [card(.spades, 10), card(.hearts, 11), card(.clubs, 13)],
            potSize: 100, amountToCall: 100, randomHandEquity: 18
        )
        XCTAssertEqual(insight.potOdds!, 50, accuracy: 0.001)
        XCTAssertTrue(insight.advice.contains("Folding may protect"))
        XCTAssertTrue(insight.advice.contains("real opponent's range can differ"))
    }

    func testGenericPreFlopPossibilitiesAreNotTreatedAsMadeDraws() {
        let insight = HandInsight.analyze(
            holeCards: [card(.spades, 4), card(.clubs, 14)],
            board: [], potSize: 30, amountToCall: 10, randomHandEquity: 56
        )
        XCTAssertEqual(insight.madeHand, "Ace high before the flop")
        XCTAssertFalse(insight.advice.contains("A draw may justify"))
    }

    func testFourFlushOnTurnBoardIsNotClaimedAsPrivateDraw() {
        let insight = HandInsight.analyze(
            holeCards: [card(.spades, 14), card(.diamonds, 7)],
            board: [card(.clubs, 2), card(.clubs, 5), card(.clubs, 9), card(.clubs, 13)],
            potSize: 100, amountToCall: 20, randomHandEquity: 40
        )
        XCTAssertFalse(insight.possibilities.contains { $0.hasPrefix("Flush draw:") })
        XCTAssertTrue(insight.possibilities.contains { $0.contains("shared flush") })
        XCTAssertTrue(insight.advice.contains("shared draw"))
    }

    func testTurnBoardStraightThreatIsExplainedAsShared() {
        let insight = HandInsight.analyze(
            holeCards: [card(.clubs, 2), card(.diamonds, 13)],
            board: [card(.spades, 5), card(.hearts, 6),
                    card(.diamonds, 7), card(.clubs, 8)],
            potSize: 100, amountToCall: 20, randomHandEquity: 40
        )
        XCTAssertTrue(insight.possibilities.contains { $0.contains("shared straight") })
        XCTAssertTrue(insight.advice.contains("shared draw"))
    }

    private func card(_ suit: Suit, _ rank: Int) -> Card {
        Card(suit: suit, rank: rank)
    }
}
