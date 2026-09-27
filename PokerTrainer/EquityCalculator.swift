//
//  EquityCalculator.swift
//  PokerTrainer
//
//  Created by PARK, SEHO on 9/6/26.
//

import Foundation

nonisolated struct EquitySituation: Hashable, Sendable {
    let hand: [Card]
    let communityCards: [Card]
    let activePlayersCount: Int
}

nonisolated final class EquityCalculator {

    nonisolated static func calculateEquity(
        playerHand: [Card],
        communityCards: [Card],
        activePlayersCount: Int,
        simulations: Int = 5000
    ) -> Double {
        var generator = SystemRandomNumberGenerator()
        return calculateEquity(
            playerHand: playerHand,
            communityCards: communityCards,
            activePlayersCount: activePlayersCount,
            simulations: simulations,
            using: &generator
        )
    }

    // An injected generator makes repeated policy comparisons reproducible.
    nonisolated static func calculateEquity<R: RandomNumberGenerator>(
        playerHand: [Card],
        communityCards: [Card],
        activePlayersCount: Int,
        simulations: Int,
        using generator: inout R
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

            let remainingCards = availableCards.shuffled(using: &generator)
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

}
