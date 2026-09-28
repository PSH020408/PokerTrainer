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
    @Published private(set) var myEquity: Double?
    @Published private(set) var saveWarning: String?
    @Published private(set) var campaign = ThreePlayerCampaign()

    private let store: LocalGameStore
    private var hasActivated = false
    private var handToken = UUID()
    private var equityRequestToken = UUID()
    private var opponentTurnToken = UUID()
    private var equityTask: Task<Void, Never>?
    private var opponentTask: Task<Void, Never>?
    private var opponentEquityCache: [EquitySituation: Double] = [:]

    init(restoring session: ThreePlayerSession? = nil, store: LocalGameStore = .shared) {
        self.store = store
        if let session {
            game = session.game
            gameMessage = session.gameMessage
            campaign = session.campaign
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
    var opponentLevel: Int { campaign.level }
    var campaignWon: Bool { campaign.won }
    var defeatedCount: Int { campaign.defeatedOpponents.count }

    var canPlayerAct: Bool {
        currentActor == .player && !isOpponentThinking && !isHandComplete
    }

    var canPlayerAllIn: Bool {
        canPlayerAct && (playerStack <= amountToCall || canPlayerRaise)
    }

    var displayedPotSize: Int {
        guard let outcome = game.handOutcome else { return game.potSize }
        return outcome.pots.reduce(0) { $0 + $1.amount }
    }

    var nextHandButtonTitle: String {
        if campaignWon { return "PLAY AGAIN ♠️" }
        if playerStack == 0 { return "RESTART TABLE ♠️" }
        if campaign.isLevelCleared { return "START LEVEL \(opponentLevel + 1) ♠️" }
        return "START NEXT HAND ♠️"
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

    func deactivate() {
        cancelPendingWork()
        hasActivated = false
    }

    func startNewHand() {
        guard game.currentActor == nil else { return }

        cancelPendingWork()

        do {
            var nextGame = game
            var nextCampaign = campaign
            if campaignWon || nextGame.state(for: .player).stack == 0 {
                nextGame = ThreePlayerGameEngine()
                nextCampaign = ThreePlayerCampaign()
            } else if campaign.isLevelCleared {
                nextCampaign.advanceLevel()
                try nextGame.replaceStacks(
                    player: nextGame.state(for: .player).stack,
                    opponentOne: OpponentStackPolicy.threePlayerPerOpponent(
                        level: nextCampaign.level,
                        playerStack: nextGame.state(for: .player).stack
                    ),
                    opponentTwo: OpponentStackPolicy.threePlayerPerOpponent(
                        level: nextCampaign.level,
                        playerStack: nextGame.state(for: .player).stack
                    )
                )
            }

            // Raise blinds with the level and after every 12 completed hands.
            // A saved hand always finishes with its original blind structure.
            let blindMultiplier = nextCampaign.blindMultiplier
            try nextGame.setBlinds(
                small: 10 * blindMultiplier,
                big: 20 * blindMultiplier
            )

            try nextGame.startHand()
            game = nextGame
            opponentEquityCache.removeAll(keepingCapacity: true)
            campaign = nextCampaign
            handToken = UUID()
            gameMessage = game.lastMessage
            myEquity = nil
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
        let previousLiveSeatCount = game.liveSeats.count
        do {
            var nextGame = game
            try nextGame.perform(action, by: seat)
            game = nextGame
            gameMessage = game.lastMessage
            processUpdatedGame(
                previousCommunityCount: previousCommunityCount,
                previousLiveSeatCount: previousLiveSeatCount
            )
            persist()
        } catch {
            gameMessage = error.localizedDescription
        }
    }

    private func processUpdatedGame(
        previousCommunityCount: Int,
        previousLiveSeatCount: Int
    ) {
        if game.isHandComplete {
            finishPresentedHand()
            return
        }

        if game.state(for: .player).isFolded {
            equityTask?.cancel()
            myEquity = nil
        } else if game.communityCards.count != previousCommunityCount
                    || game.liveSeats.count != previousLiveSeatCount {
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
        let situation = EquitySituation(
            hand: handSnapshot,
            communityCards: communitySnapshot,
            activePlayersCount: activePlayersCount
        )
        let cachedEquity = opponentEquityCache[situation]
        let context = OpponentDecisionContext(
            holeCards: handSnapshot,
            communityCards: communitySnapshot,
            equity: 0,
            potSize: game.potSize,
            amountToCall: game.amountToCall(for: seat),
            minimumRaise: game.minimumRaiseAmount,
            maximumRaise: game.maximumRaiseAmount(for: seat),
            canRaise: game.canRaise(seat: seat),
            isInPosition: game.dealer == seat,
            activePlayers: activePlayersCount,
            level: opponentLevel,
            randomRoll: Double.random(in: 0..<1),
            personality: seat == .opponentOne ? .aggressive : .cautious
        )

        isOpponentThinking = true
        gameMessage = "\(seat.displayName) is thinking..."

        opponentTask = Task { [weak self] in
            let equity: Double
            if let cachedEquity {
                equity = cachedEquity
            } else {
                let calculation = Task.detached(priority: .userInitiated) {
                    EquityCalculator.calculateEquity(
                        playerHand: handSnapshot,
                        communityCards: communitySnapshot,
                        activePlayersCount: activePlayersCount,
                        simulations: 800
                    )
                }
                equity = await withTaskCancellationHandler {
                    await calculation.value
                } onCancel: {
                    calculation.cancel()
                }
            }
            guard !Task.isCancelled else { return }

            var pricedContext = context
            pricedContext.equity = equity
            let decision = OpponentStrategy.decide(pricedContext)
            do {
                try await Task.sleep(for: .milliseconds(250))
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

            if cachedEquity == nil {
                self.opponentEquityCache[situation] = equity
            }
            self.isOpponentThinking = false
            self.applyOpponentDecision(decision, for: seat)
        }
    }

    private func applyOpponentDecision(_ decision: PokerAction, for seat: TableSeat) {
        let previousCommunityCount = game.communityCards.count
        let previousLiveSeatCount = game.liveSeats.count
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
        processUpdatedGame(
            previousCommunityCount: previousCommunityCount,
            previousLiveSeatCount: previousLiveSeatCount
        )
        persist()
    }

    private func updateEquity() {
        equityTask?.cancel()
        myEquity = nil
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
        myEquity = nil
        opponentTurnToken = UUID()
        equityRequestToken = UUID()
        isOpponentThinking = false

        let campaignEvent = campaign.recordCompletedHand(game)

        if playerStack == 0 {
            gameMessage += " Your stack is empty. Restart the table to play again."
        } else {
            switch campaignEvent {
            case .none:
                break
            case .opponentDefeated(let seat):
                gameMessage += " \(seat.displayName) defeated at this level (\(defeatedCount)/2)."
            case .levelCleared(let nextLevel):
                gameMessage += " Both opponents defeated. Level \(nextLevel) unlocked!"
            case .championshipWon:
                gameMessage += " Championship complete — you defeated both opponents at every level!"
            }
        }
    }

    private func persist() {
        do {
            try store.saveThreePlayer(ThreePlayerSession(
                game: game,
                gameMessage: gameMessage,
                campaign: campaign
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
