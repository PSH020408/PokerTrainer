//
//  PokerGameManager.swift
//  PokerTrainer
//
//  Created by PARK, SEHO on 9/6/26.
//

import Foundation
import SwiftUI
import Combine

enum GameStreet: Sendable {
    case preFlop, flop, turn, river, showdown
}

@MainActor
class PokerGameManager: ObservableObject {
    @Published var playerHand: [Card] = []
    @Published var opponentHand: [Card] = []
    @Published var communityCards: [Card] = []

    @Published var potSize: Int = 0
    @Published var playerStack: Int = 1000
    @Published var opponentStack: Int = 1000

    @Published var playerCurrentBet: Int = 0
    @Published var opponentCurrentBet: Int = 0

    @Published var opponentLevel: Int = 1
    @Published var currentStreet: GameStreet = .showdown
    @Published var isOpponentThinking: Bool = false
    @Published var gameMessage: String = "Preparing the game..."
    @Published var myEquity: Double = 0.0

    private var deck = Deck()
    private let blindAmount: Int = 20

    var amountToCall: Int {
        return max(0, opponentCurrentBet - playerCurrentBet)
    }

    var isAllIn: Bool {
        return playerStack == 0 || opponentStack == 0
    }

    func startNewHand() {
        if playerStack <= 0 {
            resolveDepletedStack()
            return
        }
        if opponentStack <= 0 {
            resolveDepletedStack()
            return
        }

        deck.reset()
        communityCards.removeAll()

        playerHand = [deck.draw()!, deck.draw()!]
        opponentHand = [deck.draw()!, deck.draw()!]

        let actualPlayerBlind = min(blindAmount, playerStack)
        let actualOpponentBlind = min(blindAmount, opponentStack)

        playerStack -= actualPlayerBlind
        opponentStack -= actualOpponentBlind
        potSize = actualPlayerBlind + actualOpponentBlind

        playerCurrentBet = actualPlayerBlind
        opponentCurrentBet = actualOpponentBlind

        currentStreet = .preFlop
        gameMessage = "Your turn — Level \(opponentLevel) opponent"

        updateEquity()
    }

    func updateEquity() {
        let pHand = playerHand
        let cCards = communityCards

        Task {
            let eq = await Task.detached(priority: .userInitiated) {
                EquityCalculator.calculateEquity(
                    playerHand: pHand,
                    communityCards: cCards,
                    activePlayersCount: 2,
                    simulations: 2000
                )
            }.value

            self.myEquity = eq
        }
    }

    // Commits the player's remaining stack and resolves the all-in sequence.
    func playerAllIn() {
        let playerAllInAmount = playerStack
        playerStack = 0
        potSize += playerAllInAmount
        playerCurrentBet += playerAllInAmount

        gameMessage = "You are all-in!"

        // Match the wager with as much of the opponent's stack as available.
        let opponentNeeded = playerCurrentBet - opponentCurrentBet
        let opponentActualCall = min(opponentNeeded, opponentStack)
        opponentStack -= opponentActualCall
        potSize += opponentActualCall
        opponentCurrentBet += opponentActualCall

        // Reveal the remaining board and proceed directly to showdown.
        proceedToNextOrShowdown()
    }

    func playerAction(_ action: PokerAction) {
        switch action {
        case .fold:
            opponentStack += potSize
            gameMessage = "You folded. The opponent wins \(potSize) chips."
            endHand()

        case .check, .call:
            let callCost = amountToCall
            if callCost > 0 {
                let actualCall = min(callCost, playerStack)
                playerStack -= actualCall
                potSize += actualCall
                playerCurrentBet += actualCall
                gameMessage = "You called \(actualCall) chips."
            } else {
                gameMessage = "You checked."
            }

            if isAllIn || playerCurrentBet == opponentCurrentBet {
                proceedToNextOrShowdown()
            } else {
                triggerOpponentTurn()
            }

        case .raise(let amount):
            if playerStack == 0 {
                playerAction(.check)
                return
            }

            let totalNeeded = amountToCall + amount
            let actualAmount = min(totalNeeded, playerStack)

            playerStack -= actualAmount
            potSize += actualAmount
            playerCurrentBet += actualAmount

            gameMessage = "You committed \(actualAmount) chips in a raise."

            if isAllIn {
                let opponentCallAmount = min(playerCurrentBet - opponentCurrentBet, opponentStack)
                opponentStack -= opponentCallAmount
                potSize += opponentCallAmount
                opponentCurrentBet += opponentCallAmount
                proceedToNextOrShowdown()
            } else {
                triggerOpponentTurn()
            }
        }
    }

    private func triggerOpponentTurn() {
        isOpponentThinking = true
        gameMessage = "Opponent is calculating..."

        let opponentHandSnapshot = opponentHand
        let cCards = communityCards
        let pSize = potSize
        let level = opponentLevel
        let opponentCallAmount = max(0, playerCurrentBet - opponentCurrentBet)

        if playerStack == 0 {
            Task {
                let opponentEquity = await Task.detached(priority: .userInitiated) {
                    EquityCalculator.calculateEquity(playerHand: opponentHandSnapshot, communityCards: cCards, activePlayersCount: 2, simulations: 2000)
                }.value

                await MainActor.run {
                    self.isOpponentThinking = false
                    if opponentEquity > 15.0 || self.opponentStack <= opponentCallAmount {
                        let actualCall = min(opponentCallAmount, self.opponentStack)
                        self.opponentStack -= actualCall
                        self.potSize += actualCall
                        self.opponentCurrentBet += actualCall
                        self.gameMessage = "The opponent called your all-in."
                    } else {
                        self.playerStack += self.potSize
                        self.gameMessage = "The opponent folded to your all-in."
                    }
                    self.proceedToNextOrShowdown()
                }
            }
            return
        }

        Task {
            let opponentEquity = await Task.detached(priority: .userInitiated) {
                EquityCalculator.calculateEquity(
                    playerHand: opponentHandSnapshot,
                    communityCards: cCards,
                    activePlayersCount: 2,
                    simulations: 2000
                )
            }.value

            let (decision, _) = await EquityCalculator.makeOpponentDecision(
                equity: opponentEquity,
                potSize: pSize,
                callAmount: opponentCallAmount,
                difficultyLevel: level
            )

            await MainActor.run {
                self.isOpponentThinking = false
                let effectiveDecision = (self.opponentStack == 0) ? .call : decision

                switch effectiveDecision {
                case .fold:
                    self.playerStack += self.potSize
                    self.gameMessage = "The opponent folds. You win \(self.potSize) chips!"
                    self.endHand()

                case .check, .call:
                    if opponentCallAmount > 0 {
                        let actualCall = min(opponentCallAmount, self.opponentStack)
                        self.opponentStack -= actualCall
                        self.potSize += actualCall
                        self.opponentCurrentBet += actualCall
                        self.gameMessage = "The opponent called \(actualCall) chips."
                    } else {
                        self.gameMessage = "The opponent checked."
                    }
                    self.proceedToNextOrShowdown()

                case .raise:
                    if self.opponentStack == 0 {
                        self.proceedToNextOrShowdown()
                        return
                    }
                    let opponentRaiseAmount = max(opponentCallAmount + 40, Int(Double(self.potSize) * 0.5))
                    let actualAmount = min(opponentRaiseAmount, self.opponentStack)

                    self.opponentStack -= actualAmount
                    self.potSize += actualAmount
                    self.opponentCurrentBet += actualAmount

                    self.gameMessage = "The opponent committed \(actualAmount) chips in a raise."
                    if self.isAllIn {
                        self.proceedToNextOrShowdown()
                    }
                }
            }
        }
    }

    private func proceedToNextOrShowdown() {
        if isAllIn {
            while currentStreet != .river && currentStreet != .showdown {
                advanceStreetOnly()
            }
            currentStreet = .showdown
            evaluateShowdown()
        } else {
            nextStreet()
        }
    }

    private func advanceStreetOnly() {
        switch currentStreet {
        case .preFlop:
            communityCards = [deck.draw()!, deck.draw()!, deck.draw()!]
            currentStreet = .flop
        case .flop:
            communityCards.append(deck.draw()!)
            currentStreet = .turn
        case .turn:
            communityCards.append(deck.draw()!)
            currentStreet = .river
        default:
            break
        }
    }

    private func nextStreet() {
        playerCurrentBet = 0
        opponentCurrentBet = 0

        switch currentStreet {
        case .preFlop:
            communityCards = [deck.draw()!, deck.draw()!, deck.draw()!]
            currentStreet = .flop
        case .flop:
            communityCards.append(deck.draw()!)
            currentStreet = .turn
        case .turn:
            communityCards.append(deck.draw()!)
            currentStreet = .river
        case .river:
            evaluateShowdown()
            return
        case .showdown:
            break
        }
        updateEquity()
    }

    private func evaluateShowdown() {
        while communityCards.count < 5 {
            if let card = deck.draw() {
                communityCards.append(card)
            }
        }

        let myScore = Evaluator.evaluate(cards: playerHand + communityCards)
        let opponentScore = Evaluator.evaluate(cards: opponentHand + communityCards)

        if myScore > opponentScore {
            playerStack += potSize
            gameMessage = "You win the showdown! (\(myScore.rank.displayName))"
        } else if opponentScore > myScore {
            opponentStack += potSize
            gameMessage = "The opponent wins the showdown. (\(opponentScore.rank.displayName))"
        } else {
            let halfPot = potSize / 2
            playerStack += halfPot
            opponentStack += (potSize - halfPot)
            gameMessage = "Split pot! The pot was divided equally."
        }
        endHand()
    }

    private func endHand() {
        currentStreet = .showdown
        playerCurrentBet = 0
        opponentCurrentBet = 0
        potSize = 0
        resolveDepletedStack()
    }

    private func resolveDepletedStack() {
        if opponentStack <= 0 {
            opponentLevel = min(4, opponentLevel + 1)
            gameMessage = "🎉 Opponent defeated! Advanced to Level \(opponentLevel)."
            opponentStack = 1000 * opponentLevel
        } else if playerStack <= 0 {
            opponentLevel = 1
            gameMessage = "💀 Chip stack depleted. Restarting from Level 1."
            playerStack = 1000
            opponentStack = 1000
        }
    }
}
