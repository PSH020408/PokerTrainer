//
//  OpponentStackPolicyTests.swift
//  PokerTrainerCoreTests
//
//  Created by PARK, SEHO on 9/28/26.
//

import XCTest
@testable import PokerTrainerCore

final class OpponentStackPolicyTests: XCTestCase {
    func testLaterHeadsUpOpponentMatchesAccumulatedPlayerStack() {
        XCTAssertEqual(OpponentStackPolicy.headsUp(level: 2, playerStack: 2_000), 2_000)
        XCTAssertEqual(OpponentStackPolicy.headsUp(level: 3, playerStack: 4_000), 4_000)
        XCTAssertEqual(OpponentStackPolicy.headsUp(level: 4, playerStack: 8_000), 8_000)
    }

    func testThreePlayerOpponentsTogetherMatchAtLeastPlayerStack() {
        XCTAssertEqual(
            OpponentStackPolicy.threePlayerPerOpponent(level: 2, playerStack: 3_000),
            2_000
        )
        XCTAssertEqual(
            OpponentStackPolicy.threePlayerPerOpponent(level: 4, playerStack: 14_001),
            7_001
        )
    }

    func testHeadsUpBlindsChangeOnlyBetweenHands() throws {
        var game = HeadsUpGameEngine()
        try game.setBlinds(small: 20, big: 40)
        try game.startHand()
        XCTAssertEqual(game.smallBlind, 20)
        XCTAssertEqual(game.bigBlind, 40)
        XCTAssertEqual(game.potSize, 60)
        XCTAssertThrowsError(try game.setBlinds(small: 40, big: 80)) { error in
            XCTAssertEqual(error as? GameRuleError, .handAlreadyInProgress)
        }
        try game.perform(.fold, by: .player)
        try game.setBlinds(small: 40, big: 80)
        try game.startHand()
        XCTAssertEqual(game.potSize, 120)
        XCTAssertTrue(game.isValidForRestoration())
    }
}
