//
//  PokerGameEngine.swift
//  PokerTrainer
//
//  Created by PARK, SEHO on 9/6/26.
//

import Foundation

nonisolated enum PokerSeat: String, Codable, Hashable, Sendable {
    case player
    case opponent

    var other: PokerSeat {
        self == .player ? .opponent : .player
    }

    var displayName: String {
        self == .player ? "You" : "The opponent"
    }
}

nonisolated enum GameStreet: String, Codable, Sendable {
    case preFlop
    case flop
    case turn
    case river
    case showdown

    var displayName: String {
        switch self {
        case .preFlop: return "Pre-Flop"
        case .flop: return "Flop"
        case .turn: return "Turn"
        case .river: return "River"
        case .showdown: return "Showdown"
        }
    }
}

nonisolated enum PokerAction: Equatable, Sendable {
    case fold
    case check
    case call
    case raise(amount: Int)
    case allIn
}

nonisolated enum HandEndReason: Equatable, Sendable {
    case fold
    case showdown
}

nonisolated struct HandOutcome: Equatable, Sendable {
    let winner: PokerSeat?
    let reason: HandEndReason
    let awardedPot: Int
    let winningRank: HandRank?
}

nonisolated enum GameRuleError: Error, Equatable, LocalizedError {
    case handAlreadyInProgress
    case handNotInProgress
    case depletedStack
    case deckExhausted
    case wrongTurn
    case cannotCheckFacingBet
    case nothingToCall
    case invalidRaise
    case actionUnavailable

    var errorDescription: String? {
        switch self {
        case .handAlreadyInProgress: return "Finish the current hand before starting another one."
        case .handNotInProgress: return "Start a hand before taking an action."
        case .depletedStack: return "Both players need chips before a hand can start."
        case .deckExhausted: return "The deck does not contain enough unique cards."
        case .wrongTurn: return "That player cannot act right now."
        case .cannotCheckFacingBet: return "A player facing a bet must call, raise, or fold."
        case .nothingToCall: return "There is no outstanding bet to call."
        case .invalidRaise: return "The requested raise is not legal."
        case .actionUnavailable: return "That action is unavailable in the current state."
        }
    }
}

// Deterministic heads-up rules engine. It owns cards, chips, positions, and turn order.
nonisolated struct HeadsUpGameEngine: Sendable {
    private(set) var playerHand: [Card] = []
    private(set) var opponentHand: [Card] = []
    private(set) var communityCards: [Card] = []

    private(set) var playerStack: Int
    private(set) var opponentStack: Int
    private(set) var potSize: Int = 0
    private(set) var playerCurrentBet: Int = 0
    private(set) var opponentCurrentBet: Int = 0

    private(set) var dealer: PokerSeat = .player
    private(set) var currentActor: PokerSeat?
    private(set) var currentStreet: GameStreet = .showdown
    private(set) var handOutcome: HandOutcome?
    private(set) var handNumber: Int = 0
    private(set) var lastMessage: String = "Preparing the game..."

    let smallBlind: Int
    let bigBlind: Int

    private var nextDealer: PokerSeat
    private var deck = Deck()
    private var dealtCards: Set<Card> = []
    private var actedThisRound: Set<PokerSeat> = []
    private var minimumRaiseIncrement: Int
    private(set) var totalChipsAtHandStart: Int = 0

    init(
        playerStack: Int = 1_000,
        opponentStack: Int = 1_000,
        smallBlind: Int = 10,
        bigBlind: Int = 20,
        firstDealer: PokerSeat = .player
    ) {
        precondition(playerStack >= 0 && opponentStack >= 0)
        precondition(smallBlind > 0 && bigBlind >= smallBlind)

        self.playerStack = playerStack
        self.opponentStack = opponentStack
        self.smallBlind = smallBlind
        self.bigBlind = bigBlind
        self.minimumRaiseIncrement = bigBlind
        self.nextDealer = firstDealer
    }

    var isHandComplete: Bool {
        handOutcome != nil
    }

    var shouldRevealOpponentCards: Bool {
        handOutcome?.reason == .showdown
    }

    var totalChipCount: Int {
        playerStack + opponentStack + potSize
    }

    var playerAmountToCall: Int {
        amountToCall(for: .player)
    }

    var canPlayerRaise: Bool {
        canRaise(seat: .player)
    }

    mutating func startHand(using suppliedDeck: Deck? = nil) throws {
        guard currentActor == nil else {
            throw GameRuleError.handAlreadyInProgress
        }
        guard playerStack > 0, opponentStack > 0 else {
            throw GameRuleError.depletedStack
        }

        playerHand.removeAll(keepingCapacity: true)
        opponentHand.removeAll(keepingCapacity: true)
        communityCards.removeAll(keepingCapacity: true)
        dealtCards.removeAll(keepingCapacity: true)
        actedThisRound.removeAll(keepingCapacity: true)

        potSize = 0
        playerCurrentBet = 0
        opponentCurrentBet = 0
        handOutcome = nil
        currentStreet = .preFlop
        minimumRaiseIncrement = bigBlind
        totalChipsAtHandStart = playerStack + opponentStack

        dealer = nextDealer
        nextDealer = dealer.other
        handNumber += 1
        deck = suppliedDeck ?? Deck()

        try dealHoleCards()
        postBlind(smallBlind, for: dealer)
        postBlind(bigBlind, for: dealer.other)

        if playerStack == 0 || opponentStack == 0 {
            let playerCannotMatch = playerCurrentBet < opponentCurrentBet && playerStack == 0
            let opponentCannotMatch = opponentCurrentBet < playerCurrentBet && opponentStack == 0

            if playerCurrentBet == opponentCurrentBet || playerCannotMatch || opponentCannotMatch {
                settleUnmatchedBets()
                try runOutAndShowdown()
                return
            }
        }

        currentActor = dealer
        let firstActorText = dealer == .player ? "You act" : "The opponent acts"
        lastMessage = "\(firstActorText) first pre-flop. Blinds: \(smallBlind)/\(bigBlind)."
    }

    mutating func perform(_ action: PokerAction, by seat: PokerSeat) throws {
        guard handOutcome == nil, currentActor != nil else {
            throw GameRuleError.handNotInProgress
        }
        guard currentActor == seat else {
            throw GameRuleError.wrongTurn
        }

        switch action {
        case .fold:
            awardFold(to: seat.other)

        case .check:
            guard amountToCall(for: seat) == 0 else {
                throw GameRuleError.cannotCheckFacingBet
            }
            actedThisRound.insert(seat)
            lastMessage = "\(seat.displayName) checked."
            try finishAction(by: seat)

        case .call:
            let callAmount = amountToCall(for: seat)
            guard callAmount > 0 else {
                throw GameRuleError.nothingToCall
            }

            let committed = min(callAmount, stack(for: seat))
            commit(committed, for: seat)
            actedThisRound.insert(seat)
            lastMessage = "\(seat.displayName) called \(committed) chips."
            try finishAction(by: seat)

        case .raise(let amount):
            try performRaise(by: amount, for: seat)
            try finishAction(by: seat)

        case .allIn:
            try performAllIn(for: seat)
            try finishAction(by: seat)
        }
    }

    func amountToCall(for seat: PokerSeat) -> Int {
        max(0, currentBet(for: seat.other) - currentBet(for: seat))
    }

    func canRaise(seat: PokerSeat) -> Bool {
        guard handOutcome == nil, currentActor == seat else { return false }
        return maximumCommit(for: seat) > amountToCall(for: seat)
    }

    mutating func replaceStacks(player: Int, opponent: Int) throws {
        guard currentActor == nil else {
            throw GameRuleError.handAlreadyInProgress
        }
        guard player >= 0, opponent >= 0 else {
            throw GameRuleError.actionUnavailable
        }

        playerStack = player
        opponentStack = opponent
        potSize = 0
        playerCurrentBet = 0
        opponentCurrentBet = 0
    }

    private mutating func dealHoleCards() throws {
        for _ in 0..<2 {
            let dealerCard = try drawUniqueCard()
            appendHoleCard(dealerCard, to: dealer)

            let otherCard = try drawUniqueCard()
            appendHoleCard(otherCard, to: dealer.other)
        }
    }

    private mutating func appendHoleCard(_ card: Card, to seat: PokerSeat) {
        if seat == .player {
            playerHand.append(card)
        } else {
            opponentHand.append(card)
        }
    }

    private mutating func postBlind(_ blind: Int, for seat: PokerSeat) {
        commit(min(blind, stack(for: seat)), for: seat)
    }

    private mutating func performRaise(by requestedRaise: Int, for seat: PokerSeat) throws {
        guard requestedRaise > 0 else {
            throw GameRuleError.invalidRaise
        }

        let callAmount = amountToCall(for: seat)
        let maxCommit = maximumCommit(for: seat)
        let actualCommit = min(callAmount + requestedRaise, maxCommit)
        let actualRaise = actualCommit - callAmount
        let isEffectiveAllIn = actualCommit == maxCommit

        guard actualRaise > 0 else {
            throw GameRuleError.invalidRaise
        }
        guard actualRaise >= minimumRaiseIncrement || isEffectiveAllIn else {
            throw GameRuleError.invalidRaise
        }

        commit(actualCommit, for: seat)
        actedThisRound = [seat]
        if actualRaise >= minimumRaiseIncrement {
            minimumRaiseIncrement = actualRaise
        }

        lastMessage = "\(seat.displayName) raised by \(actualRaise) chips."
    }

    private mutating func performAllIn(for seat: PokerSeat) throws {
        let callAmount = amountToCall(for: seat)
        let commitAmount = maximumCommit(for: seat)
        guard commitAmount > 0 else {
            throw GameRuleError.actionUnavailable
        }

        let raiseAmount = commitAmount - callAmount
        commit(commitAmount, for: seat)

        if raiseAmount > 0 {
            actedThisRound = [seat]
            if raiseAmount >= minimumRaiseIncrement {
                minimumRaiseIncrement = raiseAmount
            }
            lastMessage = "\(seat.displayName) moved all-in for an effective raise of \(raiseAmount) chips."
        } else {
            actedThisRound.insert(seat)
            lastMessage = "\(seat.displayName) called all-in for \(commitAmount) chips."
        }
    }

    private mutating func finishAction(by seat: PokerSeat) throws {
        if playerCurrentBet != opponentCurrentBet {
            let playerCannotMatch = playerCurrentBet < opponentCurrentBet && playerStack == 0
            let opponentCannotMatch = opponentCurrentBet < playerCurrentBet && opponentStack == 0

            if playerCannotMatch || opponentCannotMatch {
                settleUnmatchedBets()
                try runOutAndShowdown()
            } else {
                currentActor = seat.other
            }
            return
        }

        if playerStack == 0 || opponentStack == 0 {
            try runOutAndShowdown()
            return
        }

        if actedThisRound.count == 2 {
            try advanceStreetOrShowdown()
        } else {
            currentActor = seat.other
        }
    }

    private mutating func advanceStreetOrShowdown() throws {
        playerCurrentBet = 0
        opponentCurrentBet = 0
        actedThisRound.removeAll(keepingCapacity: true)
        minimumRaiseIncrement = bigBlind

        switch currentStreet {
        case .preFlop:
            communityCards.append(try drawUniqueCard())
            communityCards.append(try drawUniqueCard())
            communityCards.append(try drawUniqueCard())
            currentStreet = .flop
        case .flop:
            communityCards.append(try drawUniqueCard())
            currentStreet = .turn
        case .turn:
            communityCards.append(try drawUniqueCard())
            currentStreet = .river
        case .river:
            try evaluateShowdown()
            return
        case .showdown:
            throw GameRuleError.handNotInProgress
        }

        currentActor = dealer.other
        let firstActorText = dealer.other == .player ? "You act" : "The opponent acts"
        lastMessage = "\(currentStreet.displayName) dealt. \(firstActorText) first."
    }

    private mutating func runOutAndShowdown() throws {
        settleUnmatchedBets()

        while communityCards.count < 5 {
            communityCards.append(try drawUniqueCard())
        }
        try evaluateShowdown()
    }

    private mutating func evaluateShowdown() throws {
        guard playerHand.count == 2, opponentHand.count == 2, communityCards.count == 5 else {
            throw GameRuleError.deckExhausted
        }

        currentStreet = .showdown
        currentActor = nil

        let playerScore = Evaluator.evaluate(cards: playerHand + communityCards)
        let opponentScore = Evaluator.evaluate(cards: opponentHand + communityCards)
        let awardedPot = potSize

        if playerScore > opponentScore {
            playerStack += potSize
            handOutcome = HandOutcome(
                winner: .player,
                reason: .showdown,
                awardedPot: awardedPot,
                winningRank: playerScore.rank
            )
            lastMessage = "You win the showdown with \(playerScore.rank.displayName)!"
        } else if opponentScore > playerScore {
            opponentStack += potSize
            handOutcome = HandOutcome(
                winner: .opponent,
                reason: .showdown,
                awardedPot: awardedPot,
                winningRank: opponentScore.rank
            )
            lastMessage = "The opponent wins the showdown with \(opponentScore.rank.displayName)."
        } else {
            let sharedAmount = potSize / 2
            let oddChip = potSize % 2
            playerStack += sharedAmount
            opponentStack += sharedAmount
            addToStack(oddChip, for: dealer.other)
            handOutcome = HandOutcome(
                winner: nil,
                reason: .showdown,
                awardedPot: awardedPot,
                winningRank: playerScore.rank
            )
            lastMessage = "Split pot with \(playerScore.rank.displayName)."
        }

        closePot()
    }

    private mutating func awardFold(to winner: PokerSeat) {
        let awardedPot = potSize
        addToStack(potSize, for: winner)
        handOutcome = HandOutcome(
            winner: winner,
            reason: .fold,
            awardedPot: awardedPot,
            winningRank: nil
        )
        let winnerText = winner == .player ? "You win" : "The opponent wins"
        lastMessage = "\(winnerText) \(awardedPot) chips after the fold."
        closePot()
    }

    private mutating func closePot() {
        potSize = 0
        playerCurrentBet = 0
        opponentCurrentBet = 0
        currentActor = nil
        actedThisRound.removeAll(keepingCapacity: true)
    }

    private mutating func settleUnmatchedBets() {
        if playerCurrentBet > opponentCurrentBet {
            let refund = playerCurrentBet - opponentCurrentBet
            playerCurrentBet -= refund
            playerStack += refund
            potSize -= refund
        } else if opponentCurrentBet > playerCurrentBet {
            let refund = opponentCurrentBet - playerCurrentBet
            opponentCurrentBet -= refund
            opponentStack += refund
            potSize -= refund
        }
    }

    private func maximumCommit(for seat: PokerSeat) -> Int {
        let ownMaximumBet = currentBet(for: seat) + stack(for: seat)
        let opponentMaximumBet = currentBet(for: seat.other) + stack(for: seat.other)
        let effectiveTarget = min(ownMaximumBet, opponentMaximumBet)
        return max(0, effectiveTarget - currentBet(for: seat))
    }

    private mutating func commit(_ amount: Int, for seat: PokerSeat) {
        guard amount > 0 else { return }

        if seat == .player {
            playerStack -= amount
            playerCurrentBet += amount
        } else {
            opponentStack -= amount
            opponentCurrentBet += amount
        }
        potSize += amount
    }

    private func stack(for seat: PokerSeat) -> Int {
        seat == .player ? playerStack : opponentStack
    }

    private func currentBet(for seat: PokerSeat) -> Int {
        seat == .player ? playerCurrentBet : opponentCurrentBet
    }

    private mutating func addToStack(_ amount: Int, for seat: PokerSeat) {
        if seat == .player {
            playerStack += amount
        } else {
            opponentStack += amount
        }
    }

    private mutating func drawUniqueCard() throws -> Card {
        guard let card = deck.draw(), dealtCards.insert(card).inserted else {
            throw GameRuleError.deckExhausted
        }
        return card
    }
}
