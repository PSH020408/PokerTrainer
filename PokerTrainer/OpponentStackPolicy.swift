//
//  OpponentStackPolicy.swift
//  PokerTrainer
//
//  Created by PARK, SEHO on 9/28/26.
//

// Avoid giving the player an overwhelming stack advantage in later levels.
// This changes new levels only; an in-progress saved hand keeps its stacks.
nonisolated enum OpponentStackPolicy {
    static func headsUp(level: Int, playerStack: Int) -> Int {
        max(1_000 * max(1, level), max(0, playerStack))
    }

    static func threePlayerPerOpponent(level: Int, playerStack: Int) -> Int {
        max(1_000 * max(1, level), (max(0, playerStack) + 1) / 2)
    }
}
