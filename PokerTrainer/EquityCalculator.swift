//
//  EquityCalculator.swift
//  PokerTrainer
//
//  Created by PARK, SEHO on 9/6/26.
//

import Foundation

nonisolated final class EquityCalculator {

    nonisolated static func calculateEquity(
        playerHand: [Card],
        communityCards: [Card],
        activePlayersCount: Int,
        simulations: Int = 5000
    ) -> Double {
        guard simulations > 0,
              activePlayersCount >= 2,
              playerHand.count == 2,
              communityCards.count <= 5 else {
            return 0.0
        }

        let knownCards = playerHand + communityCards
        guard Set(knownCards).count == knownCards.count else {
            return 0.0
        }

        let cardsNeeded = (5 - communityCards.count) + ((activePlayersCount - 1) * 2)
        let availableCards = Deck.standardCards.filter { !knownCards.contains($0) }
        guard cardsNeeded <= availableCards.count else {
            return 0.0
        }

        var equityShare = 0.0
        var completedSimulations = 0

        for _ in 0..<simulations {
            if Task.isCancelled {
                break
            }

            let remainingCards = availableCards.shuffled()
            var nextCardIndex = 0

            var simCommunity = communityCards
            while simCommunity.count < 5 {
                simCommunity.append(remainingCards[nextCardIndex])
                nextCardIndex += 1
            }

            var opponentHands: [[Card]] = []
            for _ in 0..<(activePlayersCount - 1) {
                opponentHands.append([
                    remainingCards[nextCardIndex],
                    remainingCards[nextCardIndex + 1]
                ])
                nextCardIndex += 2
            }

            let playerScore = Evaluator.evaluate(cards: playerHand + simCommunity)
            let opponentScores = opponentHands.map {
                Evaluator.evaluate(cards: $0 + simCommunity)
            }
            let bestScore = opponentScores.reduce(playerScore, max)

            if playerScore == bestScore {
                let tiedWinners = 1 + opponentScores.filter { $0 == bestScore }.count
                equityShare += 1.0 / Double(tiedWinners)
            }
            completedSimulations += 1
        }

        guard completedSimulations > 0 else { return 0.0 }
        return (equityShare / Double(completedSimulations)) * 100.0
    }

    nonisolated static func makeOpponentDecision(
        equity: Double,
        potSize: Int,
        callAmount: Int,
        difficultyLevel: Int,
        maximumDelaySeconds: Double = 4.5
    ) async throws -> (action: PokerAction, delaySeconds: Double) {

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

        delay = min(delay, max(0, maximumDelaySeconds))
        try await Task.sleep(for: .seconds(delay))
        return (decision, delay)
    }
}
