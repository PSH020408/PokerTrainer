//
//  OpponentDifficultyBenchmarkTests.swift
//  PokerTrainerCoreTests
//
//  Created by PARK, SEHO on 9/28/26.
//

import Foundation
import XCTest
@testable import PokerTrainerCore

// Opt-in exploratory benchmark: paired deals, several fixed player policies,
// seeded equity samples, and the real betting and settlement engines.
// Results against these baselines do not establish general poker strength.
final class OpponentDifficultyBenchmarkTests: XCTestCase {
    func testSeededEquityEstimateIsReproducible() {
        let hand = [Card(suit: .spades, rank: 14), Card(suit: .hearts, rank: 13)]
        let board = [Card(suit: .clubs, rank: 8), Card(suit: .diamonds, rank: 9),
                     Card(suit: .clubs, rank: 10)]
        var firstGenerator = BenchmarkGenerator(seed: 42)
        var secondGenerator = BenchmarkGenerator(seed: 42)

        let first = EquityCalculator.calculateEquity(
            playerHand: hand, communityCards: board, activePlayersCount: 3,
            simulations: 40, using: &firstGenerator
        )
        let second = EquityCalculator.calculateEquity(
            playerHand: hand, communityCards: board, activePlayersCount: 3,
            simulations: 40, using: &secondGenerator
        )

        XCTAssertEqual(first, second)
        XCTAssertGreaterThan(first, 0)
        XCTAssertLessThan(first, 100)
    }

    func testControlledThreeSeatHandsReportLevelOutcomes() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["POKERTRAINER_BENCHMARK"] == "1",
            "Set POKERTRAINER_BENCHMARK=1 to run the exploratory match benchmark."
        )

        let config = BenchmarkConfiguration(defaultEquitySamples: 800)
        let hands = config.hands
        let equitySamples = config.equitySamples
        for level in 1...4 {
            var playerChipDelta = 0
            var botFolds = 0
            var botRaises = 0
            var botCalls = 0

            for handIndex in 0..<hands {
                var deckGenerator = BenchmarkGenerator(seed: 10_000 + UInt64(handIndex))
                let deal = Deck.standardCards.shuffled(using: &deckGenerator)
                var game = ThreePlayerGameEngine(
                    playerStack: 400, opponentOneStack: 400, opponentTwoStack: 400,
                    firstDealer: TableSeat.allCases[handIndex % 3]
                )
                try game.startHand(using: Deck(drawOrder: deal))
                var decisions = 0
                var cachedEquity: [EquitySituation: Double] = [:]

                while let actor = game.currentActor, decisions < 100 {
                    let action: PokerAction
                    if actor == .player {
                        action = config.playerStyle.action(
                            cards: game.state(for: actor).hand,
                            board: game.communityCards,
                            activePlayers: game.liveSeats.count,
                            pot: game.potSize,
                            call: game.amountToCall(for: actor),
                            minimumRaise: game.minimumRaiseAmount,
                            maximumRaise: game.maximumRaiseAmount(for: actor),
                            canRaise: game.canRaise(seat: actor),
                            handIndex: handIndex,
                            decisionIndex: decisions,
                            equitySamples: equitySamples,
                            cache: &cachedEquity
                        )
                    } else {
                        let situation = EquitySituation(
                            hand: game.state(for: actor).hand,
                            communityCards: game.communityCards,
                            activePlayersCount: game.liveSeats.count
                        )
                        let equity: Double
                        if let cached = cachedEquity[situation] {
                            equity = cached
                        } else {
                            var equityGenerator = BenchmarkGenerator(
                                seed: 1_000_000 + UInt64(handIndex * 1_000
                                    + actor.rawValue * 100 + decisions)
                            )
                            equity = EquityCalculator.calculateEquity(
                                playerHand: situation.hand,
                                communityCards: situation.communityCards,
                                activePlayersCount: situation.activePlayersCount,
                                simulations: equitySamples,
                                using: &equityGenerator
                            )
                            cachedEquity[situation] = equity
                        }
                        let context = OpponentDecisionContext(
                            holeCards: situation.hand,
                            communityCards: situation.communityCards,
                            equity: equity,
                            potSize: game.potSize,
                            amountToCall: game.amountToCall(for: actor),
                            minimumRaise: game.minimumRaiseAmount,
                            maximumRaise: game.maximumRaiseAmount(for: actor),
                            canRaise: game.canRaise(seat: actor),
                            isInPosition: game.dealer == actor,
                            activePlayers: game.liveSeats.count,
                            level: level,
                            randomRoll: Double((handIndex * 47 + decisions * 97
                                + actor.rawValue * 31) % 1_000) / 1_000,
                            personality: actor == .opponentOne ? .aggressive : .cautious
                        )
                        action = OpponentStrategy.decide(context)
                        switch action {
                        case .fold: botFolds += 1
                        case .call: botCalls += 1
                        case .raise, .allIn: botRaises += 1
                        case .check: break
                        }
                    }
                    try game.perform(action, by: actor)
                    XCTAssertEqual(game.totalChipCount, 1_200)
                    XCTAssertTrue(game.isValidForRestoration())
                    decisions += 1
                }

                XCTAssertTrue(game.isHandComplete)
                XCTAssertLessThan(decisions, 100)
                playerChipDelta += game.state(for: .player).stack - 400
            }

            print("Three-seat benchmark \(config.playerStyle.rawValue), "
                + "\(equitySamples) equity samples, level \(level): \(hands) paired deals, "
                + "player chip delta \(playerChipDelta), bot folds \(botFolds), "
                + "calls \(botCalls), raises/all-ins \(botRaises)")
        }
    }

    func testControlledHeadsUpHandsReportLevelOutcomes() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["POKERTRAINER_BENCHMARK"] == "1",
            "Set POKERTRAINER_BENCHMARK=1 to run the exploratory match benchmark."
        )

        let config = BenchmarkConfiguration(defaultEquitySamples: 1_200)
        let hands = config.hands
        let equitySamples = config.equitySamples
        for level in 1...4 {
            var playerChipDelta = 0
            var botFolds = 0
            var botRaises = 0
            var botCalls = 0

            for handIndex in 0..<hands {
                var deckGenerator = BenchmarkGenerator(seed: 20_000 + UInt64(handIndex))
                let deal = Deck.standardCards.shuffled(using: &deckGenerator)
                var game = HeadsUpGameEngine(
                    playerStack: 400, opponentStack: 400,
                    firstDealer: handIndex.isMultiple(of: 2) ? .player : .opponent
                )
                try game.startHand(using: Deck(drawOrder: deal))
                var decisions = 0
                var cachedEquity: [EquitySituation: Double] = [:]

                while let actor = game.currentActor, decisions < 100 {
                    let action: PokerAction
                    if actor == .player {
                        action = config.playerStyle.action(
                            cards: game.playerHand,
                            board: game.communityCards,
                            activePlayers: 2,
                            pot: game.potSize,
                            call: game.amountToCall(for: actor),
                            minimumRaise: game.minimumRaiseAmount,
                            maximumRaise: game.maximumRaiseAmount(for: actor),
                            canRaise: game.canRaise(seat: actor),
                            handIndex: handIndex,
                            decisionIndex: decisions,
                            equitySamples: equitySamples,
                            cache: &cachedEquity
                        )
                    } else {
                        let situation = EquitySituation(
                            hand: game.opponentHand,
                            communityCards: game.communityCards,
                            activePlayersCount: 2
                        )
                        let equity: Double
                        if let cached = cachedEquity[situation] {
                            equity = cached
                        } else {
                            var equityGenerator = BenchmarkGenerator(
                                seed: 2_000_000 + UInt64(handIndex * 1_000 + decisions)
                            )
                            equity = EquityCalculator.calculateEquity(
                                playerHand: situation.hand,
                                communityCards: situation.communityCards,
                                activePlayersCount: 2,
                                simulations: equitySamples,
                                using: &equityGenerator
                            )
                            cachedEquity[situation] = equity
                        }
                        let context = OpponentDecisionContext(
                            holeCards: situation.hand,
                            communityCards: situation.communityCards,
                            equity: equity,
                            potSize: game.potSize,
                            amountToCall: game.amountToCall(for: actor),
                            minimumRaise: game.minimumRaiseAmount,
                            maximumRaise: game.maximumRaiseAmount(for: actor),
                            canRaise: game.canRaise(seat: actor),
                            isInPosition: game.dealer == actor,
                            activePlayers: 2,
                            level: level,
                            randomRoll: Double((handIndex * 47 + decisions * 97) % 1_000)
                                / 1_000
                        )
                        action = OpponentStrategy.decide(context)
                        switch action {
                        case .fold: botFolds += 1
                        case .call: botCalls += 1
                        case .raise, .allIn: botRaises += 1
                        case .check: break
                        }
                    }
                    try game.perform(action, by: actor)
                    XCTAssertEqual(game.totalChipCount, 800)
                    XCTAssertTrue(game.isValidForRestoration())
                    decisions += 1
                }

                XCTAssertTrue(game.isHandComplete)
                XCTAssertLessThan(decisions, 100)
                playerChipDelta += game.playerStack - 400
            }

            print("Heads-up benchmark \(config.playerStyle.rawValue), "
                + "\(equitySamples) equity samples, level \(level): \(hands) paired deals, "
                + "player chip delta \(playerChipDelta), bot folds \(botFolds), "
                + "calls \(botCalls), raises/all-ins \(botRaises)")
        }
    }
}

private struct BenchmarkConfiguration {
    let hands: Int
    let equitySamples: Int
    let playerStyle: BenchmarkPlayerStyle

    init(defaultEquitySamples: Int) {
        let environment = ProcessInfo.processInfo.environment
        hands = max(1, Int(environment["POKERTRAINER_BENCHMARK_HANDS"] ?? "") ?? 48)
        equitySamples = environment["POKERTRAINER_BENCHMARK_PRODUCTION"] == "1"
            ? defaultEquitySamples : 24
        playerStyle = BenchmarkPlayerStyle(
            rawValue: environment["POKERTRAINER_BENCHMARK_STYLE"] ?? "passive"
        ) ?? .passive
    }
}

private enum BenchmarkPlayerStyle: String {
    case passive
    case selective
    case pressure

    func action(
        cards: [Card], board: [Card], activePlayers: Int,
        pot: Int, call: Int, minimumRaise: Int, maximumRaise: Int,
        canRaise: Bool, handIndex: Int, decisionIndex: Int, equitySamples: Int,
        cache: inout [EquitySituation: Double]
    ) -> PokerAction {
        if self == .passive {
            return call > 0 ? .call : .check
        }

        let situation = EquitySituation(
            hand: cards, communityCards: board, activePlayersCount: activePlayers
        )
        let equity: Double
        if let cached = cache[situation] {
            equity = cached
        } else {
            var generator = BenchmarkGenerator(
                seed: 3_000_000 + UInt64(handIndex * 1_000 + decisionIndex)
            )
            equity = EquityCalculator.calculateEquity(
                playerHand: cards,
                communityCards: board,
                activePlayersCount: activePlayers,
                simulations: equitySamples,
                using: &generator
            )
            cache[situation] = equity
        }

        let potOdds = 100 * Double(call) / Double(max(1, pot + call))
        let foldMargin = self == .selective ? 10.0 : -6.0
        if call > 0 && equity < max(18, potOdds + foldMargin) {
            return .fold
        }

        let roll = Double((handIndex * 71 + decisionIndex * 113) % 1_000) / 1_000
        let shouldRaise = self == .selective
            ? equity >= 78 && roll < 0.45
            : (equity >= 58 && roll < 0.72) || (call == 0 && equity >= 28 && roll < 0.08)
        guard canRaise, maximumRaise > 0, shouldRaise else {
            return call > 0 ? .call : .check
        }

        let fraction = self == .selective ? 0.55 : 0.75
        let raise = max(minimumRaise, Int(Double(max(1, pot)) * fraction))
        return raise >= maximumRaise ? .allIn : .raise(amount: raise)
    }
}

private struct BenchmarkGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }
}
