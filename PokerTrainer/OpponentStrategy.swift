//
//  OpponentStrategy.swift
//  PokerTrainer
//
//  Created by PARK, SEHO on 9/26/26.
//

import Foundation

nonisolated enum OpponentPersonality: Equatable, Sendable {
    case balanced
    case aggressive
    case cautious

    var decisionAdjustment: Double {
        switch self {
        case .balanced: return 0
        case .aggressive: return -4
        case .cautious: return 4
        }
    }
}

// A transparent, on-device decision policy. Equity is estimated separately by simulation.
nonisolated struct OpponentDecisionContext: Sendable {
    var holeCards: [Card]
    var communityCards: [Card]
    var equity: Double
    var potSize: Int
    var amountToCall: Int
    var minimumRaise: Int
    var maximumRaise: Int
    var canRaise: Bool
    var isInPosition: Bool
    var activePlayers: Int
    var level: Int
    var randomRoll: Double
    var personality: OpponentPersonality = .balanced
}

nonisolated enum OpponentStrategy {
    static func decide(_ context: OpponentDecisionContext) -> PokerAction {
        let level = min(max(context.level, 1), 4)
        let equity = min(max(context.equity, 0), 100)
        let roll = min(max(context.randomRoll, 0), 0.999_999)
        let isPreFlop = context.communityCards.isEmpty
        let handStrength = isPreFlop
            ? 0.65 * equity + 0.35 * preFlopGrade(context.holeCards)
            : equity
        let pot = max(0, context.potSize)
        let call = max(0, context.amountToCall)
        let potOdds = call == 0 ? 0 : 100 * Double(call) / Double(max(1, pot + call))
        let pressure = min(1, Double(call) / Double(max(1, pot)))
        let positionAdjustment = context.isInPosition ? -3.0 : 3.0
        let multiwayAdjustment = context.activePlayers > 2 ? 3.0 : 0.0
        let texture = boardTexture(context.communityCards)

        // Early levels remain approachable, but should not be passive calling
        // stations. Later levels use more position and board context.
        let foldThreshold: Double
        switch level {
        case 1:
            foldThreshold = max(21, potOdds - 8)
        case 2:
            foldThreshold = max(27, potOdds)
        case 3:
            foldThreshold = max(28, potOdds + 2 + positionAdjustment + multiwayAdjustment)
        default:
            foldThreshold = max(31, potOdds + 4 + positionAdjustment
                + multiwayAdjustment + 6 * pressure)
        }

        if call > 0 && handStrength < foldThreshold + context.personality.decisionAdjustment {
            return .fold
        }

        guard context.canRaise, context.maximumRaise > 0 else {
            return call > 0 ? .call : .check
        }

        let valueThreshold: Double
        switch level {
        case 1: valueThreshold = 74
        case 2: valueThreshold = 70 + 4 * pressure
        case 3: valueThreshold = 66 + Double(texture) * 2
            + positionAdjustment + 6 * pressure
        // Heads-up needs extra caution with thin value bets into a selective
        // caller. Keep the existing multiway threshold instead of applying
        // the same adjustment to a different betting environment.
        default: valueThreshold = 62 + (context.activePlayers == 2 ? 6 : 0)
            + Double(texture) * 3
            + multiwayAdjustment + positionAdjustment + 10 * pressure
            + (call > 0 ? 5 : 0)
        }
        let valueFrequency = [0.40, 0.55, 0.65, 0.82][level - 1]
            + (context.personality == .aggressive ? 0.08 :
                context.personality == .cautious ? -0.08 : 0)
        let valueRaise = handStrength >= valueThreshold
            + context.personality.decisionAdjustment && roll < valueFrequency
        let controlledBluff = level == 4 && call == 0 && context.isInPosition
            && texture == 0 && handStrength < valueThreshold
            && handStrength >= 32 && roll < 0.06

        guard valueRaise || controlledBluff else {
            return call > 0 ? .call : .check
        }

        let potFraction = [0.35, 0.45, 0.55, 0.65][level - 1]
            + (context.personality == .aggressive ? 0.10 :
                context.personality == .cautious ? -0.10 : 0)
        let desiredRaise = max(context.minimumRaise,
            Int(Double(max(pot, 1)) * potFraction))
        if desiredRaise >= context.maximumRaise {
            return .allIn
        }
        return .raise(amount: desiredRaise)
    }

    // This is a ranking heuristic, not a learned range or a GTO solution.
    static func preFlopGrade(_ cards: [Card]) -> Double {
        guard cards.count == 2 else { return 0 }
        let high = max(cards[0].rank, cards[1].rank)
        let low = min(cards[0].rank, cards[1].rank)
        if high == low {
            return min(100, 44 + Double(high) * 3.8)
        }

        let gap = high - low
        let suitedBonus = cards[0].suit == cards[1].suit ? 7.0 : 0.0
        let connectedBonus = gap <= 2 ? 5.0 : gap <= 4 ? 2.0 : 0.0
        let broadwayBonus = low >= 10 ? 4.0 : 0.0
        return min(100, Double(high) * 3 + Double(low) * 1.3
            + suitedBonus + connectedBonus + broadwayBonus)
    }

    // Higher values mean more coordinated or paired community cards.
    static func boardTexture(_ cards: [Card]) -> Int {
        guard cards.count >= 3 else { return 0 }
        let suitCounts = Dictionary(grouping: cards, by: \.suit).values.map(\.count)
        let ranks = cards.map(\.rank).sorted()
        let paired = Set(ranks).count < ranks.count
        let flushDraw = (suitCounts.max() ?? 0) >= 3
        let connected = zip(ranks, ranks.dropFirst()).filter { $0.1 - $0.0 <= 2 }.count >= 2
        let pairedScore = paired ? 1 : 0
        let flushScore = flushDraw ? 1 : 0
        let connectedScore = connected ? 1 : 0
        return pairedScore + flushScore + connectedScore
    }
}
