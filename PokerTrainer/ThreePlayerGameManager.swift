//
//  ThreePlayerGameManager.swift
//  PokerTrainer
//
//  Created by PARK, SEHO on 9/26/26.
//

import Combine
import Foundation

@MainActor
final class ThreePlayerGameManager: ObservableObject {
    @Published private(set) var game = ThreePlayerGameEngine()
    @Published private(set) var isOpponentThinking = false
    @Published private(set) var gameMessage = "Preparing the three-player table..."
    @Published private(set) var myEquity = 0.0
    @Published private(set) var saveWarning: String?

    let opponentLevel = 1

    private let store: LocalGameStore
    private var hasActivated = false
    private var handToken = UUID()
    private var equityRequestToken = UUID()
    private var opponentTurnToken = UUID()
    private var equityTask: Task<Void, Never>?
    private var opponentTask: Task<Void, Never>?

    init(restoring session: ThreePlayerSession? = nil, store: LocalGameStore = .shared) {
        self.store = store
        if let session {
            game = session.game
            gameMessage = session.gameMessage
        }
    }

    var playerHand: [Card] { game.state(for: .player).hand }
    var communityCards: [Card] { game.communityCards }
    var potSize: Int { game.potSize }
    var playerStack: Int { game.state(for: .player).stack }
    var amountToCall: Int { game.amountToCall(for: .player) }
    var currentStreet: GameStreet { game.currentStreet }
    var currentActor: TableSeat? { game.currentActor }
    var dealer: TableSeat { game.dealer }
    var isHandComplete: Bool { game.isHandComplete }
    var canPlayerRaise: Bool { game.canRaise(seat: .player) }

    var canPlayerAct: Bool {
        currentActor == .player && !isOpponentThinking && !isHandComplete
    }

    var canPlayerAllIn: Bool {
        canPlayerAct && (playerStack <= amountToCall || canPlayerRaise)
    }

    var displayedPotSize: Int {
        guard let outcome = game.handOutcome else { return game.potSize }
        return outcome.pots.reduce(0) { $0 + $1.amount }
            + outcome.refunds.values.reduce(0, +)
    }

    var nextHandButtonTitle: String {
        playerStack == 0 ? "RESTART TABLE ♠️" : "START NEXT HAND ♠️"
    }

    func state(for seat: TableSeat) -> TablePlayerState {
        game.state(for: seat)
    }

    func shouldRevealCards(for seat: TableSeat) -> Bool {
        game.handOutcome?.reason == .showdown && !game.state(for: seat).isFolded
    }

    func activate() {
        guard !hasActivated else { return }
        hasActivated = true

        if game.handNumber == 0 {
            startNewHand()
        } else if !game.isHandComplete {
            updateEquity()
            continueGameFlow()
        }
    }

    func startNewHand() {
        guard game.currentActor == nil else { return }

        cancelPendingWork()

        do {
            var nextGame = game
            if nextGame.state(for: .player).stack == 0 {
                nextGame = ThreePlayerGameEngine()
            } else if TableSeat.allCases.contains(where: {
                $0 != .player && nextGame.state(for: $0).stack == 0
            }) {
                try nextGame.replaceStacks(
                    player: nextGame.state(for: .player).stack,
                    opponentOne: nextGame.state(for: .opponentOne).stack == 0
                        ? 1_000 : nextGame.state(for: .opponentOne).stack,
                    opponentTwo: nextGame.state(for: .opponentTwo).stack == 0
                        ? 1_000 : nextGame.state(for: .opponentTwo).stack
                )
            }

            try nextGame.startHand()
            game = nextGame
            handToken = UUID()
            gameMessage = game.lastMessage
            myEquity = 0
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

    private func apply(_ action: PokerAction, for seat: TableSeat) {
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

        if game.state(for: .player).isFolded {
            equityTask?.cancel()
            myEquity = 0
        } else if game.communityCards.count != previousCommunityCount {
            updateEquity()
        }
        continueGameFlow()
    }

    private func continueGameFlow() {
        guard !game.isHandComplete else { return }

        if let seat = game.currentActor, seat != .player {
            triggerOpponentTurn(for: seat)
        } else {
            isOpponentThinking = false
        }
    }

    private func triggerOpponentTurn(for seat: TableSeat) {
        guard game.currentActor == seat, seat != .player else { return }

        opponentTask?.cancel()
        let requestToken = UUID()
        opponentTurnToken = requestToken
        let expectedHandToken = handToken
        let handSnapshot = game.state(for: seat).hand
        let communitySnapshot = game.communityCards
        let activePlayersCount = game.liveSeats.count
        let potSnapshot = game.potSize
        let callAmountSnapshot = game.amountToCall(for: seat)

        isOpponentThinking = true
        gameMessage = "\(seat.displayName) is thinking..."

        opponentTask = Task { [weak self] in
            let calculation = Task.detached(priority: .userInitiated) {
                EquityCalculator.calculateEquity(
                    playerHand: handSnapshot,
                    communityCards: communitySnapshot,
                    activePlayersCount: activePlayersCount,
                    simulations: 1_000
                )
            }
            let equity = await withTaskCancellationHandler {
                await calculation.value
            } onCancel: {
                calculation.cancel()
            }
            guard !Task.isCancelled else { return }

            let decision: PokerAction
            do {
                decision = try await EquityCalculator.makeOpponentDecision(
                    equity: equity,
                    potSize: potSnapshot,
                    callAmount: callAmountSnapshot,
                    difficultyLevel: 1,
                    maximumDelaySeconds: 0.7
                ).action
            } catch {
                return
            }

            guard !Task.isCancelled,
                  let self,
                  self.handToken == expectedHandToken,
                  self.opponentTurnToken == requestToken,
                  self.game.currentActor == seat,
                  !self.game.isHandComplete else {
                return
            }

            self.isOpponentThinking = false
            self.applyOpponentDecision(decision, for: seat)
        }
    }

    private func applyOpponentDecision(_ decision: PokerAction, for seat: TableSeat) {
        let previousCommunityCount = game.communityCards.count
        var nextGame = game

        do {
            try nextGame.perform(decision, by: seat)
        } catch {
            let fallback: PokerAction = nextGame.amountToCall(for: seat) > 0 ? .call : .check
            do {
                try nextGame.perform(fallback, by: seat)
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
        guard playerHand.count == 2,
              !game.state(for: .player).isFolded,
              !game.isHandComplete else { return }

        let requestToken = UUID()
        equityRequestToken = requestToken
        let expectedHandToken = handToken
        let playerHandSnapshot = playerHand
        let communitySnapshot = game.communityCards
        let activePlayersCount = game.liveSeats.count

        equityTask = Task { [weak self] in
            let calculation = Task.detached(priority: .userInitiated) {
                EquityCalculator.calculateEquity(
                    playerHand: playerHandSnapshot,
                    communityCards: communitySnapshot,
                    activePlayersCount: activePlayersCount,
                    simulations: 1_000
                )
            }
            let equity = await withTaskCancellationHandler {
                await calculation.value
            } onCancel: {
                calculation.cancel()
            }

            guard !Task.isCancelled,
                  let self,
                  self.handToken == expectedHandToken,
                  self.equityRequestToken == requestToken,
                  self.playerHand == playerHandSnapshot,
                  self.game.communityCards == communitySnapshot,
                  !self.game.state(for: .player).isFolded else {
                return
            }
            self.myEquity = equity
        }
    }

    private func finishPresentedHand() {
        opponentTask?.cancel()
        equityTask?.cancel()
        opponentTurnToken = UUID()
        equityRequestToken = UUID()
        isOpponentThinking = false

        if playerStack == 0 {
            gameMessage += " Your stack is empty. Restart the table to play again."
        } else if TableSeat.allCases.contains(where: {
            $0 != .player && game.state(for: $0).stack == 0
        }) {
            gameMessage += " A defeated opponent will rebuy for the next hand."
        }
    }

    private func persist() {
        do {
            try store.saveThreePlayer(ThreePlayerSession(
                game: game,
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
