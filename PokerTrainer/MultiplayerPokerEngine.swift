//
//  MultiplayerPokerEngine.swift
//  PokerTrainer
//
//  Created by PARK, SEHO on 9/26/26.
//

import Foundation

nonisolated enum TableSeat: Int, CaseIterable, Codable, Hashable, Sendable {
    case player
    case opponentOne
    case opponentTwo

    var displayName: String {
        switch self {
        case .player: return "You"
        case .opponentOne: return "Opponent 1"
        case .opponentTwo: return "Opponent 2"
        }
    }
}

nonisolated struct TablePlayerState: Codable, Equatable, Sendable {
    let seat: TableSeat
    fileprivate(set) var hand: [Card] = []
    fileprivate(set) var stack: Int
    fileprivate(set) var currentBet: Int = 0
    fileprivate(set) var totalContribution: Int = 0
    fileprivate(set) var isFolded: Bool = false

    var isAllIn: Bool {
        !isFolded && stack == 0
    }

    var canAct: Bool {
        !isFolded && stack > 0
    }
}

nonisolated struct SidePot: Codable, Equatable, Sendable {
    let amount: Int
    let eligibleSeats: Set<TableSeat>
}

nonisolated struct MultiplayerHandOutcome: Codable, Equatable, Sendable {
    let reason: HandEndReason
    let winnings: [TableSeat: Int]
    let refunds: [TableSeat: Int]
    let pots: [SidePot]
    let showdownRanks: [TableSeat: HandRank]
}

nonisolated enum MultiplayerRuleError: Error, Equatable, LocalizedError {
    case handAlreadyInProgress
    case handNotInProgress
    case depletedStack
    case deckExhausted
    case wrongTurn
    case cannotCheckFacingBet
    case nothingToCall
    case invalidRaise
    case raiseNotReopened
    case actionUnavailable

    var errorDescription: String? {
        switch self {
        case .handAlreadyInProgress: return "Finish the current hand before starting another one."
        case .handNotInProgress: return "Start a hand before taking an action."
        case .depletedStack: return "At least two seats need chips before a hand can start."
        case .deckExhausted: return "The deck does not contain enough unique cards."
        case .wrongTurn: return "That seat cannot act right now."
        case .cannotCheckFacingBet: return "A seat facing a bet must call, raise, or fold."
        case .nothingToCall: return "There is no outstanding bet to call."
        case .invalidRaise: return "The requested raise is not legal."
        case .raiseNotReopened: return "A short all-in did not reopen raising for that seat."
        case .actionUnavailable: return "That action is unavailable in the current state."
        }
    }
}

// Three-seat no-limit Hold'em engine with circular action order and side-pot settlement.
nonisolated struct ThreePlayerGameEngine: Codable, Sendable {
    private(set) var players: [TableSeat: TablePlayerState]
    private(set) var communityCards: [Card] = []
    private(set) var dealer: TableSeat = .player
    private(set) var smallBlindSeat: TableSeat = .opponentOne
    private(set) var bigBlindSeat: TableSeat = .opponentTwo
    private(set) var currentActor: TableSeat?
    private(set) var currentStreet: GameStreet = .showdown
    private(set) var handOutcome: MultiplayerHandOutcome?
    private(set) var handNumber: Int = 0
    private(set) var lastMessage: String = "Preparing the three-player table..."
    private(set) var totalChipsAtHandStart: Int = 0

    private(set) var smallBlind: Int
    private(set) var bigBlind: Int

    private var seatOrder: [TableSeat] { TableSeat.allCases }
    private var nextDealer: TableSeat
    private var deck = Deck()
    private var dealtCards: Set<Card> = []
    private var pendingActors: Set<TableSeat> = []
    private var raiseEligibleSeats: Set<TableSeat> = []
    private var minimumRaiseIncrement: Int

    init(
        playerStack: Int = 1_000,
        opponentOneStack: Int = 1_000,
        opponentTwoStack: Int = 1_000,
        smallBlind: Int = 10,
        bigBlind: Int = 20,
        firstDealer: TableSeat = .player
    ) {
        precondition(playerStack >= 0 && opponentOneStack >= 0 && opponentTwoStack >= 0)
        precondition(smallBlind > 0 && bigBlind >= smallBlind)

        players = [
            .player: TablePlayerState(seat: .player, stack: playerStack),
            .opponentOne: TablePlayerState(seat: .opponentOne, stack: opponentOneStack),
            .opponentTwo: TablePlayerState(seat: .opponentTwo, stack: opponentTwoStack)
        ]
        self.smallBlind = smallBlind
        self.bigBlind = bigBlind
        self.nextDealer = firstDealer
        self.minimumRaiseIncrement = bigBlind
    }

    var isHandComplete: Bool {
        handOutcome != nil
    }

    var potSize: Int {
        players.values.reduce(0) { $0 + $1.totalContribution }
    }

    var totalChipCount: Int {
        players.values.reduce(potSize) { $0 + $1.stack }
    }

    // A restored turn must contain the same cards, chips, and legal actors as the saved hand.
    func isValidForRestoration() -> Bool {
        guard smallBlind > 0, bigBlind >= smallBlind,
              minimumRaiseIncrement >= bigBlind,
              handNumber >= 0,
              Set(players.keys) == Set(seatOrder) else {
            return false
        }

        for seat in seatOrder {
            guard let player = players[seat], player.seat == seat,
                  player.stack >= 0, player.currentBet >= 0,
                  player.totalContribution >= player.currentBet else {
                return false
            }
        }

        let cardsOnTable = seatOrder.flatMap { players[$0]?.hand ?? [] } + communityCards
        let remainingCards = deck.remainingCards
        guard Set(cardsOnTable).count == cardsOnTable.count,
              Set(cardsOnTable) == dealtCards,
              Set(remainingCards).count == remainingCards.count,
              cardsOnTable.count + remainingCards.count == Deck.standardCards.count,
              Set(cardsOnTable + remainingCards) == Set(Deck.standardCards),
              pendingActors.isSubset(of: Set(actionableSeats)),
              raiseEligibleSeats.isSubset(of: pendingActors) else {
            return false
        }

        if handNumber == 0 {
            return currentActor == nil && handOutcome == nil && cardsOnTable.isEmpty
                && currentStreet == .showdown && potSize == 0
                && pendingActors.isEmpty && raiseEligibleSeats.isEmpty
                && totalChipsAtHandStart == 0
        }

        let participants = Set(seatOrder.filter { players[$0]?.hand.count == 2 })
        guard (2...3).contains(participants.count) else { return false }
        let expectedSmallBlind = participants.count == 2
            ? dealer : nextParticipatingSeat(after: dealer, among: participants)
        guard participants.contains(dealer),
              seatOrder.allSatisfy({ seat in
                  participants.contains(seat) ||
                      (players[seat]?.hand.isEmpty == true
                       && players[seat]?.stack == 0
                       && players[seat]?.isFolded == true)
              }),
              smallBlindSeat == expectedSmallBlind,
              bigBlindSeat == nextParticipatingSeat(
                  after: smallBlindSeat, among: participants
              ),
              totalChipCount == totalChipsAtHandStart,
              nextDealer == nextSeat(after: dealer) else {
            return false
        }

        let expectedBoardCount: Int
        switch currentStreet {
        case .preFlop: expectedBoardCount = 0
        case .flop: expectedBoardCount = 3
        case .turn: expectedBoardCount = 4
        case .river, .showdown: expectedBoardCount = 5
        }
        guard communityCards.count == expectedBoardCount else { return false }

        if let outcome = handOutcome {
            guard currentActor == nil, pendingActors.isEmpty,
                  raiseEligibleSeats.isEmpty, potSize == 0 else {
                return false
            }
            if outcome.reason == .showdown {
                return currentStreet == .showdown
                    && Set(outcome.showdownRanks.keys) == Set(liveSeats)
            }
            return currentStreet != .showdown && liveSeats.count == 1
        }

        guard let actor = currentActor else { return false }
        return liveSeats.count >= 2 && pendingActors.contains(actor)
            && currentStreet != .showdown
    }

    var liveSeats: [TableSeat] {
        seatOrder.filter { players[$0]?.isFolded == false }
    }

    var actionableSeats: [TableSeat] {
        seatOrder.filter { players[$0]?.canAct == true }
    }

    func state(for seat: TableSeat) -> TablePlayerState {
        guard let state = players[seat] else {
            preconditionFailure("Every table seat must have a state.")
        }
        return state
    }

    func amountToCall(for seat: TableSeat) -> Int {
        max(0, highestCurrentBet - state(for: seat).currentBet)
    }

    func canRaise(seat: TableSeat) -> Bool {
        guard handOutcome == nil,
              currentActor == seat,
              raiseEligibleSeats.contains(seat) else {
            return false
        }
        return state(for: seat).stack > amountToCall(for: seat)
    }

    var minimumRaiseAmount: Int { minimumRaiseIncrement }

    func maximumRaiseAmount(for seat: TableSeat) -> Int {
        max(0, state(for: seat).stack - amountToCall(for: seat))
    }

    mutating func startHand(using suppliedDeck: Deck? = nil) throws {
        guard currentActor == nil else {
            throw MultiplayerRuleError.handAlreadyInProgress
        }
        let participatingSeats = Set(seatOrder.filter { state(for: $0).stack > 0 })
        guard participatingSeats.count >= 2 else {
            throw MultiplayerRuleError.depletedStack
        }

        resetHandState()
        totalChipsAtHandStart = players.values.reduce(0) { $0 + $1.stack }
        dealer = participatingSeats.contains(nextDealer)
            ? nextDealer : nextParticipatingSeat(after: nextDealer, among: participatingSeats)
        nextDealer = nextSeat(after: dealer)
        smallBlindSeat = participatingSeats.count == 2
            ? dealer : nextParticipatingSeat(after: dealer, among: participatingSeats)
        bigBlindSeat = nextParticipatingSeat(
            after: smallBlindSeat, among: participatingSeats
        )
        handNumber += 1
        deck = suppliedDeck ?? Deck()

        try dealHoleCards()
        postBlind(smallBlind, for: smallBlindSeat)
        postBlind(bigBlind, for: bigBlindSeat)

        currentStreet = .preFlop
        beginBettingRound(after: bigBlindSeat, includeAllActionableSeats: true)

        if pendingActors.isEmpty {
            try runOutAndShowdown()
            return
        }

        let actor = currentActor ?? .player
        let verb = actor == .player ? "act" : "acts"
        lastMessage = "\(actor.displayName) \(verb) first pre-flop. Blinds: \(smallBlind)/\(bigBlind)."
    }

    mutating func perform(_ action: PokerAction, by seat: TableSeat) throws {
        guard handOutcome == nil, currentActor != nil else {
            throw MultiplayerRuleError.handNotInProgress
        }
        guard currentActor == seat, pendingActors.contains(seat) else {
            throw MultiplayerRuleError.wrongTurn
        }

        switch action {
        case .fold:
            updatePlayer(seat) { player in
                player.isFolded = true
            }
            pendingActors.remove(seat)
            raiseEligibleSeats.remove(seat)
            lastMessage = "\(seat.displayName) folded."

        case .check:
            guard amountToCall(for: seat) == 0 else {
                throw MultiplayerRuleError.cannotCheckFacingBet
            }
            pendingActors.remove(seat)
            raiseEligibleSeats.remove(seat)
            lastMessage = "\(seat.displayName) checked."

        case .call:
            let callAmount = amountToCall(for: seat)
            guard callAmount > 0 else {
                throw MultiplayerRuleError.nothingToCall
            }
            let committed = min(callAmount, state(for: seat).stack)
            commit(committed, for: seat)
            pendingActors.remove(seat)
            raiseEligibleSeats.remove(seat)
            lastMessage = "\(seat.displayName) called \(committed) chips."

        case .raise(let amount):
            try performRaise(by: amount, for: seat)

        case .allIn:
            try performAllIn(for: seat)
        }

        try finishAction(after: seat)
    }

    mutating func replaceStacks(
        player: Int,
        opponentOne: Int,
        opponentTwo: Int
    ) throws {
        guard currentActor == nil else {
            throw MultiplayerRuleError.handAlreadyInProgress
        }
        guard player >= 0, opponentOne >= 0, opponentTwo >= 0 else {
            throw MultiplayerRuleError.actionUnavailable
        }

        updatePlayer(.player) { $0.stack = player }
        updatePlayer(.opponentOne) { $0.stack = opponentOne }
        updatePlayer(.opponentTwo) { $0.stack = opponentTwo }
        resetContributions()
    }

    mutating func setBlinds(small: Int, big: Int) throws {
        guard currentActor == nil else {
            throw MultiplayerRuleError.handAlreadyInProgress
        }
        guard small > 0, big >= small else {
            throw MultiplayerRuleError.actionUnavailable
        }
        smallBlind = small
        bigBlind = big
        minimumRaiseIncrement = big
    }

    private var highestCurrentBet: Int {
        players.values.map(\.currentBet).max() ?? 0
    }

    private mutating func resetHandState() {
        communityCards.removeAll(keepingCapacity: true)
        dealtCards.removeAll(keepingCapacity: true)
        pendingActors.removeAll(keepingCapacity: true)
        raiseEligibleSeats.removeAll(keepingCapacity: true)
        handOutcome = nil
        currentStreet = .showdown
        minimumRaiseIncrement = bigBlind

        for seat in seatOrder {
            updatePlayer(seat) { player in
                player.hand.removeAll(keepingCapacity: true)
                player.currentBet = 0
                player.totalContribution = 0
                player.isFolded = player.stack == 0
            }
        }
    }

    private mutating func dealHoleCards() throws {
        let participants = Set(seatOrder.filter { state(for: $0).stack > 0 })
        let firstRecipient = nextParticipatingSeat(after: dealer, among: participants)
        for _ in 0..<2 {
            var recipient = firstRecipient
            for _ in 0..<participants.count {
                let card = try drawUniqueCard()
                updatePlayer(recipient) { player in
                    player.hand.append(card)
                }
                recipient = nextParticipatingSeat(after: recipient, among: participants)
            }
        }
    }

    private func nextParticipatingSeat(
        after seat: TableSeat,
        among participants: Set<TableSeat>
    ) -> TableSeat {
        var candidate = seat
        for _ in seatOrder {
            candidate = nextSeat(after: candidate)
            if participants.contains(candidate) { return candidate }
        }
        preconditionFailure("At least one seat must participate in the hand.")
    }

    private mutating func postBlind(_ amount: Int, for seat: TableSeat) {
        commit(min(amount, state(for: seat).stack), for: seat)
    }

    private mutating func beginBettingRound(
        after anchor: TableSeat,
        includeAllActionableSeats: Bool
    ) {
        let available = Set(actionableSeats)

        if available.count <= 1 {
            pendingActors = Set(available.filter { amountToCall(for: $0) > 0 })
        } else if includeAllActionableSeats {
            pendingActors = available
        } else {
            pendingActors = available
        }

        raiseEligibleSeats = pendingActors
        currentActor = nextPendingSeat(after: anchor)
    }

    private mutating func performRaise(by requestedRaise: Int, for seat: TableSeat) throws {
        guard raiseEligibleSeats.contains(seat) else {
            throw MultiplayerRuleError.raiseNotReopened
        }
        guard requestedRaise > 0 else {
            throw MultiplayerRuleError.invalidRaise
        }

        let callAmount = amountToCall(for: seat)
        let actualCommit = min(callAmount + requestedRaise, state(for: seat).stack)
        let actualRaise = actualCommit - callAmount
        let isAllIn = actualCommit == state(for: seat).stack

        guard actualRaise > 0 else {
            throw MultiplayerRuleError.invalidRaise
        }
        guard actualRaise >= minimumRaiseIncrement || isAllIn else {
            throw MultiplayerRuleError.invalidRaise
        }

        commit(actualCommit, for: seat)
        updatePendingSeats(afterAggressionBy: seat, raiseAmount: actualRaise)
        lastMessage = "\(seat.displayName) raised by \(actualRaise) chips."
    }

    private mutating func performAllIn(for seat: TableSeat) throws {
        let stack = state(for: seat).stack
        guard stack > 0 else {
            throw MultiplayerRuleError.actionUnavailable
        }

        let callAmount = amountToCall(for: seat)
        let raiseAmount = stack - callAmount

        if raiseAmount > 0 {
            guard raiseEligibleSeats.contains(seat) else {
                throw MultiplayerRuleError.raiseNotReopened
            }
        }

        commit(stack, for: seat)

        if raiseAmount > 0 {
            updatePendingSeats(afterAggressionBy: seat, raiseAmount: raiseAmount)
            lastMessage = "\(seat.displayName) moved all-in with a \(raiseAmount)-chip raise."
        } else {
            pendingActors.remove(seat)
            raiseEligibleSeats.remove(seat)
            lastMessage = "\(seat.displayName) called all-in for \(stack) chips."
        }
    }

    private mutating func updatePendingSeats(
        afterAggressionBy seat: TableSeat,
        raiseAmount: Int
    ) {
        let fullRaise = raiseAmount >= minimumRaiseIncrement
        if fullRaise {
            minimumRaiseIncrement = raiseAmount
            pendingActors = Set(actionableSeats.filter { $0 != seat })
            raiseEligibleSeats = pendingActors
        } else {
            pendingActors.remove(seat)
            raiseEligibleSeats.remove(seat)
            let newHighestBet = highestCurrentBet
            for otherSeat in actionableSeats where otherSeat != seat {
                if state(for: otherSeat).currentBet < newHighestBet {
                    pendingActors.insert(otherSeat)
                }
            }
        }
    }

    private mutating func finishAction(after actingSeat: TableSeat) throws {
        pruneUnavailableSeats()

        if liveSeats.count == 1, let winner = liveSeats.first {
            awardFold(to: winner)
            return
        }

        if pendingActors.isEmpty {
            if actionableSeats.count <= 1 {
                try runOutAndShowdown()
            } else {
                try advanceStreetOrShowdown()
            }
            return
        }

        currentActor = nextPendingSeat(after: actingSeat)
        if currentActor == nil {
            try runOutAndShowdown()
        }
    }

    private mutating func pruneUnavailableSeats() {
        for seat in seatOrder where !state(for: seat).canAct {
            pendingActors.remove(seat)
            raiseEligibleSeats.remove(seat)
        }
    }

    private mutating func advanceStreetOrShowdown() throws {
        for seat in seatOrder {
            updatePlayer(seat) { $0.currentBet = 0 }
        }
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
            throw MultiplayerRuleError.handNotInProgress
        }

        beginBettingRound(after: dealer, includeAllActionableSeats: true)
        if pendingActors.isEmpty {
            try runOutAndShowdown()
            return
        }

        let actor = currentActor ?? .player
        let verb = actor == .player ? "act" : "acts"
        lastMessage = "\(currentStreet.displayName) dealt. \(actor.displayName) \(verb) first."
    }

    private mutating func runOutAndShowdown() throws {
        while communityCards.count < 5 {
            communityCards.append(try drawUniqueCard())
        }
        try evaluateShowdown()
    }

    private mutating func evaluateShowdown() throws {
        guard communityCards.count == 5,
              liveSeats.allSatisfy({ state(for: $0).hand.count == 2 }) else {
            throw MultiplayerRuleError.deckExhausted
        }

        currentStreet = .showdown
        currentActor = nil

        var scores: [TableSeat: HandScore] = [:]
        for seat in liveSeats {
            scores[seat] = Evaluator.evaluate(cards: state(for: seat).hand + communityCards)
        }

        let settlement = buildPotsAndRefunds()
        var winnings: [TableSeat: Int] = [:]

        for (seat, refund) in settlement.refunds {
            addToStack(refund, for: seat)
        }

        for pot in settlement.pots {
            let eligibleScores = pot.eligibleSeats.compactMap { seat -> (TableSeat, HandScore)? in
                guard let score = scores[seat] else { return nil }
                return (seat, score)
            }
            guard let bestScore = eligibleScores.map(\.1).max() else { continue }
            let winners = eligibleScores
                .filter { $0.1 == bestScore }
                .map(\.0)

            distribute(pot.amount, among: winners, recording: &winnings)
        }

        let ranks = scores.mapValues(\.rank)
        handOutcome = MultiplayerHandOutcome(
            reason: .showdown,
            winnings: winnings,
            refunds: settlement.refunds,
            pots: settlement.pots,
            showdownRanks: ranks
        )

        let humanWinnings = winnings[.player, default: 0]
        if humanWinnings > 0 {
            lastMessage = "You receive \(humanWinnings) chips at showdown."
        } else {
            lastMessage = "The opponents win the showdown pots."
        }
        closeHand()
    }

    private func buildPotsAndRefunds() -> (
        pots: [SidePot],
        refunds: [TableSeat: Int]
    ) {
        let levels = Set(players.values.map(\.totalContribution).filter { $0 > 0 }).sorted()
        var previousLevel = 0
        var pots: [SidePot] = []
        var refunds: [TableSeat: Int] = [:]

        for level in levels {
            let contributors = Set(seatOrder.filter {
                state(for: $0).totalContribution >= level
            })
            let amount = (level - previousLevel) * contributors.count

            if contributors.count == 1, let onlyContributor = contributors.first {
                refunds[onlyContributor, default: 0] += amount
            } else if amount > 0 {
                let eligible = Set(contributors.filter {
                    !state(for: $0).isFolded
                })
                pots.append(SidePot(amount: amount, eligibleSeats: eligible))
            }
            previousLevel = level
        }

        return (pots, refunds)
    }

    private mutating func distribute(
        _ amount: Int,
        among winners: [TableSeat],
        recording winnings: inout [TableSeat: Int]
    ) {
        guard !winners.isEmpty else { return }

        let equalShare = amount / winners.count
        var remainder = amount % winners.count
        for winner in winners {
            addToStack(equalShare, for: winner)
            winnings[winner, default: 0] += equalShare
        }

        for seat in clockwiseSeats(startingAfter: dealer) where remainder > 0 {
            guard winners.contains(seat) else { continue }
            addToStack(1, for: seat)
            winnings[seat, default: 0] += 1
            remainder -= 1
        }
    }

    private mutating func awardFold(to winner: TableSeat) {
        let settlement = buildPotsAndRefunds()
        for (seat, refund) in settlement.refunds {
            addToStack(refund, for: seat)
        }
        let amount = settlement.pots.reduce(0) { $0 + $1.amount }
        addToStack(amount, for: winner)
        handOutcome = MultiplayerHandOutcome(
            reason: .fold,
            winnings: [winner: amount],
            refunds: settlement.refunds,
            pots: settlement.pots,
            showdownRanks: [:]
        )
        let winnerText = winner == .player ? "You win" : "\(winner.displayName) wins"
        lastMessage = "\(winnerText) \(amount) chips after the folds."
        closeHand()
    }

    private mutating func closeHand() {
        resetContributions()
        currentActor = nil
        pendingActors.removeAll(keepingCapacity: true)
        raiseEligibleSeats.removeAll(keepingCapacity: true)
    }

    private mutating func resetContributions() {
        for seat in seatOrder {
            updatePlayer(seat) { player in
                player.currentBet = 0
                player.totalContribution = 0
            }
        }
    }

    private mutating func commit(_ amount: Int, for seat: TableSeat) {
        guard amount > 0 else { return }
        updatePlayer(seat) { player in
            player.stack -= amount
            player.currentBet += amount
            player.totalContribution += amount
        }
    }

    private mutating func addToStack(_ amount: Int, for seat: TableSeat) {
        guard amount > 0 else { return }
        updatePlayer(seat) { $0.stack += amount }
    }

    private mutating func updatePlayer(
        _ seat: TableSeat,
        _ update: (inout TablePlayerState) -> Void
    ) {
        guard var player = players[seat] else {
            preconditionFailure("Every table seat must have a state.")
        }
        update(&player)
        players[seat] = player
    }

    private func nextSeat(after seat: TableSeat) -> TableSeat {
        guard let index = seatOrder.firstIndex(of: seat) else {
            preconditionFailure("The seat must be part of the table.")
        }
        return seatOrder[(index + 1) % seatOrder.count]
    }

    private func nextPendingSeat(after seat: TableSeat) -> TableSeat? {
        var candidate = nextSeat(after: seat)
        for _ in seatOrder.indices {
            if pendingActors.contains(candidate) {
                return candidate
            }
            candidate = nextSeat(after: candidate)
        }
        return nil
    }

    private func clockwiseSeats(startingAfter seat: TableSeat) -> [TableSeat] {
        var result: [TableSeat] = []
        var candidate = nextSeat(after: seat)
        for _ in seatOrder.indices {
            result.append(candidate)
            candidate = nextSeat(after: candidate)
        }
        return result
    }

    private mutating func drawUniqueCard() throws -> Card {
        guard let card = deck.draw(), dealtCards.insert(card).inserted else {
            throw MultiplayerRuleError.deckExhausted
        }
        return card
    }
}
