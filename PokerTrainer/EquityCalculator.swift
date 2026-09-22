//
//  EquityCalculator.swift
//  PokerTrainer
//
//  Created by PARK, SEHO on 9/6/26.
//

import Foundation

// Legal actions shared by the player and the computer opponent.
enum PokerAction: Sendable {
    case fold
    case check
    case call
    case raise(amount: Int)
}

class EquityCalculator {

    nonisolated static func calculateEquity(
        playerHand: [Card],
        communityCards: [Card],
        activePlayersCount: Int,
        simulations: Int = 5000
    ) -> Double {
        var wins = 0.0

        for _ in 0..<simulations {
            let deck = Deck()
            let knownCards = playerHand + communityCards

            var simCommunity = communityCards
            while simCommunity.count < 5 {
                if let card = deck.draw(), !knownCards.contains(card) {
                    simCommunity.append(card)
                }
            }

            var opponentHands: [[Card]] = []
            for _ in 0..<(activePlayersCount - 1) {
                var oppHand: [Card] = []
                while oppHand.count < 2 {
                    if let card = deck.draw(), !knownCards.contains(card), !simCommunity.contains(card) {
                        oppHand.append(card)
                    }
                }
                opponentHands.append(oppHand)
            }

            let myScore = Evaluator.evaluate(cards: playerHand + simCommunity)
            var iWon = true

            for oppHand in opponentHands {
                let oppScore = Evaluator.evaluate(cards: oppHand + simCommunity)
                if oppScore > myScore {
                    iWon = false
                    break
                }
            }
            if iWon { wins += 1.0 }
        }

        return (wins / Double(simulations)) * 100.0
    }

    nonisolated static func makeOpponentDecision(
        equity: Double,
        potSize: Int,
        callAmount: Int,
        difficultyLevel: Int
    ) async -> (action: PokerAction, delaySeconds: Double) {

        let noiseFactor: Double
        switch difficultyLevel {
        case 1: noiseFactor = 0.35
        case 2: noiseFactor = 0.20
        case 3: noiseFactor = 0.08
        default: noiseFactor = 0.0
        }

        let totalPot = potSize + callAmount
        let requiredOdds = totalPot > 0 ? (Double(callAmount) / Double(totalPot)) * 100.0 : 0.0

        var delay = Double.random(in: 1.0...2.5)
        let isBluffing = Double.random(in: 0...1) < noiseFactor
        var decision: PokerAction

        if isBluffing {
            if equity < 40.0 {
                decision = .raise(amount: potSize / 2)
                delay = Double.random(in: 3.0...4.5)
            } else {
                decision = callAmount == 0 ? .check : .call
                delay = 0.3
            }
        } else {
            if equity < requiredOdds {
                decision = callAmount == 0 ? .check : .fold
            } else if equity > 70.0 {
                decision = .raise(amount: potSize)
            } else {
                decision = callAmount == 0 ? .check : .call
            }
        }

        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        return (decision, delay)
    }
}
