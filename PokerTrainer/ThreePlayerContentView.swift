//
//  ThreePlayerContentView.swift
//  PokerTrainer
//
//  Created by PARK, SEHO on 9/26/26.
//

import SwiftUI

struct ThreePlayerTableView: View {
    @StateObject private var gameManager: ThreePlayerGameManager
    @State private var showingCoach = false
    @State private var payoutAwards: [PotAward] = []
    @State private var payoutEvent = 0
    let returnToMenu: () -> Void

    init(restoring session: ThreePlayerSession?, returnToMenu: @escaping () -> Void) {
        _gameManager = StateObject(wrappedValue: ThreePlayerGameManager(restoring: session))
        self.returnToMenu = returnToMenu
    }

    private var handInsight: HandInsight {
        HandInsight.analyze(
            holeCards: gameManager.playerHand,
            board: gameManager.communityCards,
            potSize: gameManager.potSize,
            amountToCall: gameManager.amountToCall,
            randomHandEquity: gameManager.myEquity
        )
    }

    var body: some View {
        ZStack {
            Color(red: 0.1, green: 0.35, blue: 0.18)
                .ignoresSafeArea()

            VStack(spacing: 10) {
                tableHeader

                HStack(alignment: .top, spacing: 8) {
                    opponentPanel(for: .opponentOne)
                    opponentPanel(for: .opponentTwo)
                }

                Spacer(minLength: 4)
                boardPanel
                Spacer(minLength: 4)
                playerPanel
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            PotAwardEffect(
                awards: payoutAwards,
                eventID: payoutEvent,
                threeSeatTable: true
            )
        }
        .onAppear {
            gameManager.activate()
        }
        .onDisappear {
            gameManager.deactivate()
        }
        .onChange(of: gameManager.game.handOutcome) { _, outcome in
            guard outcome != nil,
                  let result = HandResultSummary.threePlayer(gameManager.game) else { return }
            payoutAwards = result.awards
            payoutEvent += 1
        }
        .sheet(isPresented: $showingCoach) {
            HandCoachSheet(
                holeCards: gameManager.playerHand,
                board: gameManager.communityCards,
                insight: handInsight,
                randomHandEquity: gameManager.myEquity,
                isFolded: gameManager.state(for: .player).isFolded
            )
        }
    }

    private var tableHeader: some View {
        VStack(spacing: 3) {
            HStack {
                Text("PokerTrainer")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Button(action: leaveTable) {
                    Label("MENU", systemImage: "house.fill")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                        .frame(minWidth: 70, minHeight: 44)
                }
                .accessibilityHint("Save progress and choose another table")
            }
            HStack {
                Text("1 vs 2 · Level \(gameManager.opponentLevel)/4 · Defeated \(gameManager.defeatedCount)/2")
                    .font(.caption)
                    .foregroundColor(.yellow)
                Spacer()
                Text("\(gameManager.currentStreet.displayName) · Dealer: \(gameManager.dealer.displayName)")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding(10)
        .background(Color.black.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func opponentPanel(for seat: TableSeat) -> some View {
        let player = gameManager.state(for: seat)
        let isActing = gameManager.currentActor == seat

        return VStack(spacing: 5) {
            HStack(spacing: 4) {
                Image(systemName: "cpu")
                    .foregroundColor(isActing ? .yellow : .white)
                Text(seat.displayName)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .font(.caption.bold())
            .foregroundColor(.white)

            Text(player.hand.isEmpty && gameManager.game.handNumber > 0
                 ? "\(player.stack) chips"
                 : "\(player.stack) chips · \(positionLabel(for: seat))")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.8))
                .monospacedDigit()

            HStack(spacing: 4) {
                if player.hand.isEmpty {
                    Text("OUT")
                        .font(.caption.bold())
                        .foregroundColor(.white.opacity(0.7))
                } else {
                    ForEach(Array(player.hand.enumerated()), id: \.offset) { index, card in
                        DealtCardView(
                            delay: 0.08 + Double(seat.rawValue) * 0.10
                                + Double(index) * 0.12
                        ) {
                            FlippingCardView(
                                card: card,
                                faceUp: gameManager.shouldRevealCards(for: seat)
                            )
                        }
                        .id("\(seat.rawValue)-\(gameManager.game.handNumber)-\(index)")
                    }
                }
            }

            Text(player.hand.isEmpty ? "ELIMINATED" :
                player.isFolded ? "FOLDED" :
                player.isAllIn ? "ALL-IN" : "Bet: \(player.currentBet)")
                .font(.caption2.bold())
                .foregroundColor(player.isFolded ? .gray : .yellow)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .padding(.horizontal, 4)
        .background(isActing ? Color.yellow.opacity(0.22) : Color.black.opacity(0.32))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(isActing ? Color.yellow : Color.clear, lineWidth: 2)
        }
    }

    private var boardPanel: some View {
        VStack(spacing: 10) {
            Text("\(gameManager.isHandComplete ? "LAST POT" : "POT"): \(gameManager.displayedPotSize) CHIPS")
                .font(.headline)
                .foregroundColor(.yellow)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.5))
                .clipShape(Capsule())
                .monospacedDigit()
                .overlay {
                    ChipFlowEffect(
                        stack: gameManager.playerStack,
                        sourceX: 0,
                        sourceY: 70
                    )
                }
                .overlay {
                    ChipFlowEffect(
                        stack: gameManager.state(for: .opponentOne).stack,
                        sourceX: -24,
                        sourceY: -70
                    )
                }
                .overlay {
                    ChipFlowEffect(
                        stack: gameManager.state(for: .opponentTwo).stack,
                        sourceX: 24,
                        sourceY: -70
                    )
                }

            HStack(spacing: 5) {
                ForEach(0..<5, id: \.self) { index in
                    if index < gameManager.communityCards.count {
                        DealtCardView(delay: 0.05 + Double(index % 3) * 0.11) {
                            CardView(card: gameManager.communityCards[index])
                        }
                            .id("board-\(gameManager.game.handNumber)-\(index)")
                    } else {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.12))
                            .frame(width: 45, height: 65)
                    }
                }
            }

            if let result = HandResultSummary.threePlayer(gameManager.game) {
                HandResultBanner(result: result)
            }
        }
    }

    private var playerPanel: some View {
        VStack(spacing: 10) {
            HStack {
                Text("You · \(gameManager.playerStack) chips · \(positionLabel(for: .player))")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                    .monospacedDigit()
                Spacer()
                if gameManager.currentActor == .player {
                    Text("YOUR TURN")
                        .font(.caption2.bold())
                        .foregroundColor(.yellow)
                }
            }

            HStack(spacing: 6) {
                ForEach(Array(gameManager.playerHand.enumerated()), id: \.offset) { index, card in
                    DealtCardView(delay: 0.30 + Double(index) * 0.12) {
                        CardView(card: card)
                    }
                        .id("player-\(gameManager.game.handNumber)-\(index)")
                }
                if !gameManager.playerHand.isEmpty {
                    Button {
                        showingCoach = true
                    } label: {
                        Image(systemName: "exclamationmark.bubble.fill")
                            .font(.title2)
                            .foregroundStyle(.yellow)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Open hand coach")
                    .accessibilityHint("See your current hand, possible draws, and a strategy tip")
                }
                Spacer()
                if !gameManager.isHandComplete,
                   !gameManager.state(for: .player).isFolded {
                    if let equity = gameManager.myEquity {
                        Text("Random-hand equity \(String(format: "%.1f", equity))%")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.85))
                    } else {
                        Text("Calculating equity...")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }

            if !gameManager.playerHand.isEmpty {
                Text(gameManager.state(for: .player).isFolded
                     ? "FOLDED · Your cards cannot win this pot"
                     : "MADE HAND: \(handInsight.madeHand)")
                    .font(.caption.bold())
                    .foregroundStyle(.yellow)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text(gameManager.gameMessage)
                .font(.caption)
                .foregroundColor(.yellow)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(3)
                .padding(8)
                .background(Color.black.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            if let warning = gameManager.saveWarning {
                Text(warning)
                    .font(.caption2)
                    .foregroundColor(.orange)
            }

            if gameManager.isHandComplete || gameManager.playerHand.isEmpty {
                Button {
                    gameManager.startNewHand()
                } label: {
                    Text(gameManager.nextHandButtonTitle)
                        .font(.headline)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .background(Color.yellow)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            } else {
                actionControls
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.48))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var smallRaiseAmount: Int {
        max(gameManager.game.minimumRaiseAmount, max(gameManager.potSize / 2, 50))
    }

    private var largeRaiseAmount: Int {
        max(gameManager.game.minimumRaiseAmount, max(gameManager.potSize, 100))
    }

    private var actionControls: some View {
        VStack(spacing: 7) {
            HStack(spacing: 7) {
                Button("FOLD") {
                    gameManager.playerAction(.fold)
                }
                .buttonStyle(ActionButtonStyle(color: .gray))

                Button(gameManager.amountToCall > 0
                       ? "CALL \(min(gameManager.amountToCall, gameManager.playerStack))"
                       : "CHECK") {
                    gameManager.playerAction(gameManager.amountToCall > 0 ? .call : .check)
                }
                .buttonStyle(ActionButtonStyle(color: .green))

                Button("ALL-IN") {
                    gameManager.playerAction(.allIn)
                }
                .buttonStyle(ActionButtonStyle(color: .purple))
                .disabled(!gameManager.canPlayerAllIn)
            }

            HStack(spacing: 7) {
                Button("RAISE +\(smallRaiseAmount)") {
                    gameManager.playerAction(.raise(amount: smallRaiseAmount))
                }
                .buttonStyle(ActionButtonStyle(color: .orange))

                Button("RAISE +\(largeRaiseAmount)") {
                    gameManager.playerAction(.raise(amount: largeRaiseAmount))
                }
                .buttonStyle(ActionButtonStyle(color: .red))
            }
            .disabled(!gameManager.canPlayerRaise)
        }
        .disabled(!gameManager.canPlayerAct)
    }

    private func positionLabel(for seat: TableSeat) -> String {
        if gameManager.dealer == seat && gameManager.game.smallBlindSeat == seat {
            return "D / SB"
        }
        if gameManager.dealer == seat { return "D" }
        if gameManager.game.smallBlindSeat == seat { return "SB" }
        return "BB"
    }

    private func leaveTable() {
        gameManager.deactivate()
        returnToMenu()
    }
}
