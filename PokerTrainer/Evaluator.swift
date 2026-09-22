//
//  Evaluator.swift
//  PokerTrainer
//
//  Created by PARK, SEHO on 9/6/26.
//

import Foundation

// Poker hand categories ordered from weakest to strongest.
nonisolated enum HandRank: Int, Comparable, Sendable {
    case highCard = 1
    case onePair
    case twoPair
    case threeOfAKind
    case straight
    case flush
    case fullHouse
    case fourOfAKind
    case straightFlush

    var displayName: String {
        switch self {
        case .highCard: return "High Card"
        case .onePair: return "One Pair"
        case .twoPair: return "Two Pair"
        case .threeOfAKind: return "Three of a Kind"
        case .straight: return "Straight"
        case .flush: return "Flush"
        case .fullHouse: return "Full House"
        case .fourOfAKind: return "Four of a Kind"
        case .straightFlush: return "Straight Flush"
        }
    }

    nonisolated static func < (lhs: HandRank, rhs: HandRank) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

// Final result of a hand evaluation.
nonisolated struct HandScore: Comparable, Sendable {
    let rank: HandRank
    let tieBreakers: [Int] // Ranked values used to break ties, in descending order.

    // Compares both the hand category and all tie-break values.
    nonisolated static func == (lhs: HandScore, rhs: HandScore) -> Bool {
        return lhs.rank == rhs.rank && lhs.tieBreakers == rhs.tieBreakers
    }

    // Orders scores by category first, then by tie-break values.
    nonisolated static func < (lhs: HandScore, rhs: HandScore) -> Bool {
        if lhs.rank != rhs.rank {
            return lhs.rank < rhs.rank
        }
        for (l, r) in zip(lhs.tieBreakers, rhs.tieBreakers) {
            if l != r {
                return l < r
            }
        }
        return lhs.tieBreakers.count < rhs.tieBreakers.count
    }

    // Provides an explicit greater-than comparison for score evaluation.
    nonisolated static func > (lhs: HandScore, rhs: HandScore) -> Bool {
        return rhs < lhs
    }
}

// Stateless poker hand evaluator that can run outside the main actor.
nonisolated final class Evaluator: @unchecked Sendable {

    // Finds the strongest five-card hand from the available cards.
    static func evaluate(cards: [Card]) -> HandScore {
        guard cards.count >= 5 else {
            return HandScore(rank: .highCard, tieBreakers: [])
        }

        // Seven cards produce 21 five-card combinations; return the best score.
        let combinations = getCombinations(cards, k: 5)
        guard let firstCombination = combinations.first else {
            return HandScore(rank: .highCard, tieBreakers: [])
        }

        var bestScore = evaluate5Cards(firstCombination)
        for combo in combinations.dropFirst() {
            let score = evaluate5Cards(combo)
            if score > bestScore {
                bestScore = score
            }
        }

        return bestScore
    }

    // Evaluates one five-card hand.
    private static func evaluate5Cards(_ cards: [Card]) -> HandScore {
        let sortedCards = cards.sorted { $0.rank > $1.rank }
        let ranks = sortedCards.map { $0.rank }

        let isFlush = Set(sortedCards.map { $0.suit }).count == 1
        let isStraight = checkStraight(ranks)

        // Counts occurrences of each rank, for example [14: 2, 10: 3].
        var rankCounts: [Int: Int] = [:]
        for r in ranks { rankCounts[r, default: 0] += 1 }

        let counts = rankCounts.values.sorted(by: >)

        // 1. Straight flush
        if isFlush && isStraight.isStraight {
            return HandScore(rank: .straightFlush, tieBreakers: [isStraight.highRank])
        }

        // 2. Four of a kind
        if counts == [4, 1] {
            let fourRank = rankCounts.first(where: { $0.value == 4 })!.key
            let kicker = rankCounts.first(where: { $0.value == 1 })!.key
            return HandScore(rank: .fourOfAKind, tieBreakers: [fourRank, kicker])
        }

        // 3. Full house
        if counts == [3, 2] {
            let threeRank = rankCounts.first(where: { $0.value == 3 })!.key
            let pairRank = rankCounts.first(where: { $0.value == 2 })!.key
            return HandScore(rank: .fullHouse, tieBreakers: [threeRank, pairRank])
        }

        // 4. Flush
        if isFlush {
            return HandScore(rank: .flush, tieBreakers: ranks)
        }

        // 5. Straight
        if isStraight.isStraight {
            return HandScore(rank: .straight, tieBreakers: [isStraight.highRank])
        }

        // 6. Three of a kind
        if counts == [3, 1, 1] {
            let threeRank = rankCounts.first(where: { $0.value == 3 })!.key
            let kickers = rankCounts.filter({ $0.value == 1 }).keys.sorted(by: >)
            return HandScore(rank: .threeOfAKind, tieBreakers: [threeRank] + kickers)
        }

        // 7. Two pair
        if counts == [2, 2, 1] {
            let pairs = rankCounts.filter({ $0.value == 2 }).keys.sorted(by: >)
            let kicker = rankCounts.first(where: { $0.value == 1 })!.key
            return HandScore(rank: .twoPair, tieBreakers: pairs + [kicker])
        }

        // 8. One pair
        if counts == [2, 1, 1, 1] {
            let pair = rankCounts.first(where: { $0.value == 2 })!.key
            let kickers = rankCounts.filter({ $0.value == 1 }).keys.sorted(by: >)
            return HandScore(rank: .onePair, tieBreakers: [pair] + kickers)
        }

        // 9. High card
        return HandScore(rank: .highCard, tieBreakers: ranks)
    }

    // Detects a standard or ace-low straight and returns its high card.
    private static func checkStraight(_ ranks: [Int]) -> (isStraight: Bool, highRank: Int) {
        let uniqueRanks = Array(Set(ranks)).sorted(by: >)
        guard uniqueRanks.count == 5 else { return (false, 0) }

        if uniqueRanks[0] - uniqueRanks[4] == 4 {
            return (true, uniqueRanks[0])
        }
        if uniqueRanks == [14, 5, 4, 3, 2] {
            return (true, 5)
        }
        return (false, 0)
    }

    // Recursively generates all combinations of the requested size.
    private static func getCombinations<T>(_ elements: [T], k: Int) -> [[T]] {
        if k == 0 { return [[]] }
        if elements.isEmpty { return [] }
        let head = elements[0]
        let tail = Array(elements.dropFirst())
        let withHead = getCombinations(tail, k: k - 1).map { [head] + $0 }
        let withoutHead = getCombinations(tail, k: k)
        return withHead + withoutHead
    }
}
