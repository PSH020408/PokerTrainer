//
//  HandInsight.swift
//  PokerTrainer
//
//  Created by PARK, SEHO on 9/28/26.
//

import Foundation

// Explain visible cards and a betting price without pretending to know an
// opponent's hidden range or promising an optimal action.
nonisolated struct HandInsight: Sendable {
    let madeHand: String
    let possibilities: [String]
    let potOdds: Double?
    let advice: String

    static func analyze(
        holeCards: [Card],
        board: [Card],
        potSize: Int,
        amountToCall: Int,
        randomHandEquity: Double?
    ) -> HandInsight {
        guard holeCards.count == 2 else {
            return HandInsight(
                madeHand: "No active hand",
                possibilities: ["Start a hand to see card-based guidance."],
                potOdds: nil,
                advice: "This guide uses only cards already visible to you."
            )
        }

        let cards = holeCards + board
        let madeHand: String
        if board.isEmpty {
            madeHand = holeCards[0].rank == holeCards[1].rank
                ? "Pocket pair"
                : "\(rankName(max(holeCards[0].rank, holeCards[1].rank))) high before the flop"
        } else {
            madeHand = Evaluator.evaluate(cards: cards).rank.displayName
        }

        var possibilities: [String] = []
        var sharedBoardDraw = false
        if board.isEmpty {
            if holeCards[0].rank == holeCards[1].rank {
                possibilities.append("A matching card can make three of a kind.")
            }
            if holeCards[0].suit == holeCards[1].suit {
                possibilities.append("Suited starting cards can develop a flush.")
            }
            if abs(holeCards[0].rank - holeCards[1].rank) <= 2 {
                possibilities.append("Close ranks can develop a straight.")
            }
            if possibilities.isEmpty {
                possibilities.append("Watch the flop for pairs and direct straight or flush draws.")
            }
        } else if board.count == 3 || board.count == 4 {
            let suitCounts = Dictionary(grouping: cards, by: \.suit).mapValues(\.count)
            if suitCounts.values.contains(4) {
                let boardSuitCounts = Dictionary(grouping: board, by: \.suit).mapValues(\.count)
                if boardSuitCounts.values.contains(4) {
                    sharedBoardDraw = true
                    possibilities.append("Four cards of one suit are on the board. A matching river can make a shared flush; an opponent holding that suit may already have one.")
                } else {
                    possibilities.append("Flush draw: one more card of the same suit completes a flush.")
                }
            }

            let madeRank = Evaluator.evaluate(cards: cards).rank
            let ranks = Set(cards.map(\.rank))
            if madeRank < .straight && !containsStraight(ranks) {
                let completingRanks = (2...14).filter { missing in
                    !ranks.contains(missing) && containsStraight(ranks.union([missing]))
                }
                if !completingRanks.isEmpty {
                    let count = completingRanks.count
                    possibilities.append(
                        "Straight draw: \(count) distinct rank\(count == 1 ? "" : "s") can complete it."
                    )
                    if board.count == 4 {
                        let boardRanks = Set(board.map(\.rank))
                        if completingRanks.contains(where: { missing in
                            containsStraight(boardRanks.union([missing]))
                        }) {
                            sharedBoardDraw = true
                            possibilities.append("The board can also complete a shared straight; the same river card may help an opponent.")
                        }
                    }
                }
            }
            switch madeRank {
            case .highCard:
                possibilities.append("Pairing a hole-card rank can make one pair.")
            case .onePair:
                possibilities.append("A matching rank can make three of a kind; another pair can make two pair.")
            case .twoPair:
                possibilities.append("Matching either pair rank can make a full house.")
            case .threeOfAKind:
                possibilities.append("A board pair can make a full house; the fourth matching rank makes four of a kind.")
            default:
                break
            }
            if possibilities.isEmpty {
                possibilities.append("No direct one-card straight or flush draw detected.")
            }
        } else {
            possibilities.append("The board is complete; no more cards will be dealt.")
            if Evaluator.evaluate(cards: board) == Evaluator.evaluate(cards: cards) {
                possibilities.append("The board plays your best five cards; an opponent may share this hand.")
            }
        }

        let call = max(0, amountToCall)
        let potOdds = call > 0
            ? 100 * Double(call) / Double(max(1, potSize + call))
            : nil
        let madeRank = board.count >= 3 ? Evaluator.evaluate(cards: cards).rank : .highCard
        let hasDirectDraw = possibilities.contains {
            $0.hasPrefix("Flush draw:") || $0.hasPrefix("Straight draw:")
        }
        let advice: String
        if let potOdds {
            if let randomHandEquity, randomHandEquity + 5 < potOdds {
                advice = "The call price is higher than your estimated equity against random hands. Folding may protect your chips; a real opponent's range can differ."
            } else if madeRank >= .twoPair && board.count >= 3 {
                advice = "You have a made hand. Consider whether weaker hands can call a value bet, but watch for stronger board combinations."
            } else if sharedBoardDraw {
                advice = "A completing board card may help every player. Do not call solely for a shared draw; weigh the call price and the opponent's betting pattern."
            } else if hasDirectDraw {
                advice = "A draw may justify a small call. Compare the call price with your chance to improve and avoid chasing at any cost."
            } else {
                advice = "Compare the call price with your estimated equity and the opponent's betting pattern; random-hand equity is not a read on their cards."
            }
        } else if madeRank >= .twoPair && board.count >= 3 {
            advice = "A strong made hand may be worth a value bet if weaker hands can call. Check the board for better possible hands."
        } else if sharedBoardDraw {
            advice = "A completing board card may help every player. Do not value a shared draw like a private one."
        } else if hasDirectDraw {
            advice = "Checking can show you another card for free. A bet needs a clear value or bluff reason, not just a hopeful draw."
        } else {
            advice = "Checking controls the pot. Bet when you can explain which weaker hands call or which stronger hands might fold."
        }

        return HandInsight(
            madeHand: madeHand,
            possibilities: possibilities,
            potOdds: potOdds,
            advice: advice
        )
    }

    private static func rankName(_ rank: Int) -> String {
        switch rank {
        case 11: return "Jack"
        case 12: return "Queen"
        case 13: return "King"
        case 14: return "Ace"
        default: return "\(rank)"
        }
    }

    private static func containsStraight(_ ranks: Set<Int>) -> Bool {
        for low in 1...10 {
            if (low...(low + 4)).allSatisfy({ rank in
                ranks.contains(rank == 1 ? 14 : rank)
            }) {
                return true
            }
        }
        return false
    }
}
