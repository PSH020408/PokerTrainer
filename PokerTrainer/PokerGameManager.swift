//
//  PokerGameManager.swift
//  PokerTrainer
//
//  Created by PARK, SEHO on 9/6/26.
//

import Combine
import Foundation

@MainActor
final class PokerGameManager: ObservableObject {
    @Published private(set) var game = HeadsUpGameEngine()
    @Published private(set) var opponentLevel: Int = 1
    @Published private(set) var isOpponentThinking: Bool = false
    @Published private(set) var gameMessage: String = "Preparing the game..."
    @Published private(set) var myEquity: Double = 0.0
    @Published private(set) var campaignWon: Bool = false
    @Published private(set) var saveWarning: String?

    private let maximumOpponentLevel = 4
    private let store: LocalGameStore
    private var hasActivated = false
    private var handToken = UUID()
    private var equityRequestToken = UUID()
    private var opponentTurnToken = UUID()
    private var equityTask: Task<Void, Never>?
    private var opponentTask: Task<Void, Never>?

    init(restoring session: HeadsUpSession? = nil, store: LocalGameStore = .shared) {
        self.store = store
        if let session {
            game = session.game
            opponentLevel = session.opponentLevel
            campaignWon = session.campaignWon
            gameMessage = session.gameMessage
        }
    }

    var playerHand: [Card] { game.playerHand }
    var opponentHand: [Card] { game.opponentHand }
    var communityCards: [Card] { game.communityCards }
    var potSize: Int { game.potSize }
    var playerStack: Int { game.playerStack }
    var opponentStack: Int { game.opponentStack }
    var playerCurrentBet: Int { game.playerCurrentBet }
    var opponentCurrentBet: Int { game.opponentCurrentBet }
    var amountToCall: Int { game.playerAmountToCall }
    var currentStreet: GameStreet { game.currentStreet }
    var dealer: PokerSeat { game.dealer }
    var currentActor: PokerSeat? { game.currentActor }
    var shouldRevealOpponentCards: Bool { game.shouldRevealOpponentCards }
    var isHandComplete: Bool { game.isHandComplete }
    var canPlayerRaise: Bool { game.canPlayerRaise }

    var canPlayerAct: Bool {
        currentActor == .player && !isOpponentThinking && !isHandComplete
    }

    var nextHandButtonTitle: String {
        if campaignWon {
            return "START NEW CAMPAIGN ♠️"
        }
        if playerStack == 0 {
            return "RESTART FROM LEVEL 1 ♠️"
        }
        if opponentStack == 0 {
            return "FACE THE NEXT OPPONENT ♠️"
        }
        return "START NEXT HAND ♠️"
    }

    func activate() {
        guard !hasActivated else { return }
        hasActivated = true

        if game.handNumber == 0 {
            startNewHand()
        } else if game.isHandComplete {
            if let outcome = game.handOutcome, outcome.reason == .showdown {
                myEquity = outcome.winner == .player ? 100.0
                    : outcome.winner == .opponent ? 0.0 : 50.0
            }
        } else {
            updateEquity()
            continueGameFlow()
        }
    }

    func startNewHand() {
        guard game.currentActor == nil else { return }

        cancelPendingWork()

        do {
            var nextGame = game
            var nextLevel = opponentLevel
            var nextCampaignWon = campaignWon

            if campaignWon || nextGame.playerStack == 0 {
                nextLevel = 1
                nextCampaignWon = false
                try nextGame.replaceStacks(player: 1_000, opponent: 1_000)
            } else if nextGame.opponentStack == 0 {
                nextLevel = min(maximumOpponentLevel, opponentLevel + 1)
                try nextGame.replaceStacks(
                    player: nextGame.playerStack,
                    opponent: 1_000 * nextLevel
                )
            }

            try nextGame.startHand()
            game = nextGame
            opponentLevel = nextLevel
            campaignWon = nextCampaignWon

            handToken = UUID()
            gameMessage = game.lastMessage
            myEquity = 0.0
            updateEquity()
            continueGameFlow()
            persist()
        } catch {
            gameMessage = error.localizedDescription
        }
    }

    func playerAction(_ action: PokerAction) {
        guard canPlayerAct else {
            gameMessage = "Wait until it is your turn."
            return
        }

        apply(action, for: .player)
    }

    func playerAllIn() {
        playerAction(.allIn)
    }

    private func apply(_ action: PokerAction, for seat: PokerSeat) {
        let previousCommunityCount = game.communityCards.count

        do {
            var nextGame = game
            try nextGame.perform(action, by: seat)
            game = nextGame
            gameMessage = game.lastMessage
            processUpdatedGame(previousCommunityCount: previousCommunityCount)
            persist()
        } catch {
            gameMessage = error.localizedDescription
        }
    }

    private func processUpdatedGame(previousCommunityCount: Int) {
        if game.isHandComplete {
            finishPresentedHand()
            return
        }

        if game.communityCards.count != previousCommunityCount {
            updateEquity()
        }
        continueGameFlow()
    }

    private func continueGameFlow() {
        guard !game.isHandComplete else { return }

        if game.currentActor == .opponent {
            triggerOpponentTurn()
        } else {
            isOpponentThinking = false
        }
    }

    private func triggerOpponentTurn() {
        guard game.currentActor == .opponent, !game.isHandComplete else { return }

        opponentTask?.cancel()
        let requestToken = UUID()
        opponentTurnToken = requestToken
        let expectedHandToken = handToken
        let opponentHandSnapshot = game.opponentHand
        let communitySnapshot = game.communityCards
        let potSnapshot = game.potSize
        let callAmountSnapshot = game.amountToCall(for: .opponent)
        let levelSnapshot = opponentLevel

        isOpponentThinking = true
        gameMessage = "The opponent is calculating..."

        opponentTask = Task { [weak self] in
            let opponentEquity = await Task.detached(priority: .userInitiated) {
                EquityCalculator.calculateEquity(
                    playerHand: opponentHandSnapshot,
                    communityCards: communitySnapshot,
                    activePlayersCount: 2,
                    simulations: 2_000
                )
            }.value

            guard !Task.isCancelled else { return }

            let decision: PokerAction
            do {
                decision = try await EquityCalculator.makeOpponentDecision(
                    equity: opponentEquity,
                    potSize: potSnapshot,
                    callAmount: callAmountSnapshot,
                    difficultyLevel: levelSnapshot
                ).action
            } catch {
                return
            }

            guard !Task.isCancelled,
                  let self,
                  self.handToken == expectedHandToken,
                  self.opponentTurnToken == requestToken,
                  self.game.currentActor == .opponent,
                  !self.game.isHandComplete else {
                return
            }

            self.isOpponentThinking = false
            self.applyOpponentDecision(decision)
        }
    }

    private func applyOpponentDecision(_ decision: PokerAction) {
        let previousCommunityCount = game.communityCards.count
        var nextGame = game

        do {
            try nextGame.perform(decision, by: .opponent)
        } catch {
            let fallback: PokerAction = nextGame.amountToCall(for: .opponent) > 0 ? .call : .check
            do {
                try nextGame.perform(fallback, by: .opponent)
            } catch {
                gameMessage = error.localizedDescription
                return
            }
        }

        game = nextGame
        gameMessage = game.lastMessage
        processUpdatedGame(previousCommunityCount: previousCommunityCount)
        persist()
    }

    private func updateEquity() {
        equityTask?.cancel()

        guard game.playerHand.count == 2, !game.isHandComplete else { return }

        let requestToken = UUID()
        equityRequestToken = requestToken
        let expectedHandToken = handToken
        let playerHandSnapshot = game.playerHand
        let communitySnapshot = game.communityCards

        equityTask = Task { [weak self] in
            let equity = await Task.detached(priority: .userInitiated) {
                EquityCalculator.calculateEquity(
                    playerHand: playerHandSnapshot,
                    communityCards: communitySnapshot,
                    activePlayersCount: 2,
                    simulations: 2_000
                )
            }.value

            guard !Task.isCancelled,
                  let self,
                  self.handToken == expectedHandToken,
                  self.equityRequestToken == requestToken,
                  self.game.playerHand == playerHandSnapshot,
                  self.game.communityCards == communitySnapshot else {
                return
            }

            self.myEquity = equity
        }
    }

    private func finishPresentedHand() {
        opponentTask?.cancel()
        equityTask?.cancel()
        isOpponentThinking = false

        if let outcome = game.handOutcome, outcome.reason == .showdown {
            if outcome.winner == .player {
                myEquity = 100.0
            } else if outcome.winner == .opponent {
                myEquity = 0.0
            } else {
                myEquity = 50.0
            }
        }

        if opponentStack == 0 {
            if opponentLevel >= maximumOpponentLevel {
                campaignWon = true
                gameMessage += " Championship complete — you defeated every opponent!"
            } else {
                gameMessage += " Level \(opponentLevel + 1) is now unlocked."
            }
        } else if playerStack == 0 {
            gameMessage += " Your chip stack is empty."
        }
    }

    private func persist() {
        do {
            try store.saveHeadsUp(HeadsUpSession(
                game: game,
                opponentLevel: opponentLevel,
                campaignWon: campaignWon,
                gameMessage: gameMessage
            ))
            saveWarning = nil
        } catch {
            saveWarning = "Progress could not be saved on this device."
        }
    }

    private func cancelPendingWork() {
        opponentTask?.cancel()
        equityTask?.cancel()
        opponentTurnToken = UUID()
        equityRequestToken = UUID()
        isOpponentThinking = false
    }
}
