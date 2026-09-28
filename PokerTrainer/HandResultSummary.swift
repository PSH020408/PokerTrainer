//
//  HandResultSummary.swift
//  PokerTrainer
//
//  Created by PARK, SEHO on 9/28/26.
//

import Foundation

nonisolated enum AwardSeat: Int, Sendable {
    case player
    case opponentOne
    case opponentTwo
}

nonisolated struct PotAward: Equatable, Sendable {
    let seat: AwardSeat
    let chips: Int
}

// A player-facing explanation of the engine's settled outcome. Refunds are
// deliberately excluded: they were never won from another player.
nonisolated struct HandResultSummary: Sendable {
    let title: String
    let details: [String]
    let awards: [PotAward]

    static func headsUp(_ game: HeadsUpGameEngine) -> HandResultSummary? {
        guard let outcome = game.handOutcome else { return nil }

        let title: String
        let awards: [PotAward]
        switch outcome.winner {
        case .player:
            title = "YOU WIN THE POT"
            awards = [PotAward(seat: .player, chips: outcome.awardedPot)]
        case .opponent:
            title = "OPPONENT WINS THE POT"
            awards = [PotAward(seat: .opponentOne, chips: outcome.awardedPot)]
        case nil:
            title = "SPLIT POT"
            let playerShare = outcome.awardedPot / 2
                + (outcome.awardedPot.isMultiple(of: 2) || game.dealer.other != .player ? 0 : 1)
            awards = [
                PotAward(seat: .player, chips: playerShare),
                PotAward(seat: .opponentOne, chips: outcome.awardedPot - playerShare)
            ]
        }

        var details = ["\(outcome.awardedPot) chips awarded"]
        if let rank = outcome.winningRank {
            details.append("Winning hand: \(rank.displayName)")
            if game.playerHand.count == 2, game.communityCards.count == 5 {
                let playerRank = Evaluator.evaluate(
                    cards: game.playerHand + game.communityCards
                ).rank
                details.append("Your hand: \(playerRank.displayName)")
            }
        } else {
            details.append("Won after a fold; hidden cards stay private")
        }
        return HandResultSummary(title: title, details: details, awards: awards)
    }

    static func threePlayer(_ game: ThreePlayerGameEngine) -> HandResultSummary? {
        guard let outcome = game.handOutcome else { return nil }
        let awards = TableSeat.allCases.compactMap { seat -> PotAward? in
            let chips = outcome.winnings[seat, default: 0]
            guard chips > 0 else { return nil }
            let awardSeat: AwardSeat
            switch seat {
            case .player: awardSeat = .player
            case .opponentOne: awardSeat = .opponentOne
            case .opponentTwo: awardSeat = .opponentTwo
            }
            return PotAward(seat: awardSeat, chips: chips)
        }

        let title: String
        if awards.count > 1 {
            title = "POTS SHARED OR SPLIT"
        } else if awards.first?.seat == .player {
            title = "YOU WIN THE POT"
        } else {
            title = "OPPONENT WINS THE POT"
        }

        var details = TableSeat.allCases.compactMap { seat -> String? in
            let chips = outcome.winnings[seat, default: 0]
            guard chips > 0 else { return nil }
            let name = seat == .player ? "You" : seat.displayName
            if let rank = outcome.showdownRanks[seat] {
                return "\(name) +\(chips) · \(rank.displayName)"
            }
            return "\(name) +\(chips) · won after folds"
        }
        if outcome.winnings[.player, default: 0] == 0,
           let playerRank = outcome.showdownRanks[.player] {
            details.append("Your hand: \(playerRank.displayName)")
        }
        if game.state(for: .player).isFolded {
            details.append("You folded and were not eligible for the pot")
        }
        return HandResultSummary(title: title, details: details, awards: awards)
    }
}
