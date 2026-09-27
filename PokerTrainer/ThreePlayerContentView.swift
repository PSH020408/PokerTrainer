//
//  ThreePlayerContentView.swift
//  PokerTrainer
//
//  Created by PARK, SEHO on 9/26/26.
//

import SwiftUI

struct ThreePlayerTableView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var gameManager: ThreePlayerGameManager
    let returnToMenu: () -> Void

    init(restoring session: ThreePlayerSession?, returnToMenu: @escaping () -> Void) {
        _gameManager = StateObject(wrappedValue: ThreePlayerGameManager(restoring: session))
        self.returnToMenu = returnToMenu
    }

    private var dealAnimation: Animation? {
        reduceMotion ? nil : .easeOut(duration: 0.28)
    }

    private var cardTransition: AnyTransition {
        reduceMotion ? .identity : .offset(y: -20).combined(with: .opacity)
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
        }
        .onAppear {
            gameManager.activate()
        }
    }

    private var tableHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text("PokerTrainer")
                    .font(.headline)
                    .foregroundColor(.white)
                Text("1 vs 2 · Level \(gameManager.opponentLevel)/4 · Defeated \(gameManager.defeatedCount)/2")
                    .font(.caption)
                    .foregroundColor(.yellow)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(gameManager.currentStreet.displayName)
                Text("Dealer: \(gameManager.dealer.displayName)")
            }
            .font(.caption)
            .foregroundColor(.white.opacity(0.8))
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
                .contentTransition(.numericText())
                .animation(dealAnimation, value: player.stack)

            HStack(spacing: 4) {
                if player.hand.isEmpty {
                    Text("OUT")
                        .font(.caption.bold())
                        .foregroundColor(.white.opacity(0.7))
                } else {
                    ForEach(Array(player.hand.enumerated()), id: \.offset) { index, card in
                        FlippingCardView(
                            card: card,
                            faceUp: gameManager.shouldRevealCards(for: seat)
                        )
                        .id("\(seat.rawValue)-\(gameManager.game.handNumber)-\(index)")
                        .transition(cardTransition)
                    }
                }
            }
            .animation(dealAnimation, value: gameManager.game.handNumber)

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
                .contentTransition(.numericText())
                .animation(dealAnimation, value: gameManager.displayedPotSize)
                .overlay {
                    ChipFlowEffect(
                        stack: gameManager.playerStack,
                        handComplete: gameManager.isHandComplete,
                        sourceX: 0,
                        sourceY: 70
                    )
                }
                .overlay {
                    ChipFlowEffect(
                        stack: gameManager.state(for: .opponentOne).stack,
                        handComplete: gameManager.isHandComplete,
                        sourceX: -24,
                        sourceY: -70
                    )
                }
                .overlay {
                    ChipFlowEffect(
                        stack: gameManager.state(for: .opponentTwo).stack,
                        handComplete: gameManager.isHandComplete,
                        sourceX: 24,
                        sourceY: -70
                    )
                }

            HStack(spacing: 5) {
                ForEach(0..<5, id: \.self) { index in
                    if index < gameManager.communityCards.count {
                        CardView(card: gameManager.communityCards[index])
                            .id("board-\(gameManager.game.handNumber)-\(index)")
                            .transition(cardTransition)
                    } else {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.12))
                            .frame(width: 45, height: 65)
                    }
                }
            }
            .animation(dealAnimation, value: gameManager.communityCards.count)
            .animation(dealAnimation, value: gameManager.game.handNumber)
        }
    }

    private var playerPanel: some View {
        VStack(spacing: 10) {
            HStack {
                Text("You · \(gameManager.playerStack) chips · \(positionLabel(for: .player))")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                    .contentTransition(.numericText())
                    .animation(dealAnimation, value: gameManager.playerStack)
                Spacer()
                if gameManager.currentActor == .player {
                    Text("YOUR TURN")
                        .font(.caption2.bold())
                        .foregroundColor(.yellow)
                }
            }

            HStack(spacing: 6) {
                ForEach(Array(gameManager.playerHand.enumerated()), id: \.offset) { index, card in
                    CardView(card: card)
                        .id("player-\(gameManager.game.handNumber)-\(index)")
                        .transition(cardTransition)
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
            .animation(dealAnimation, value: gameManager.game.handNumber)

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
                if gameManager.isHandComplete {
                    Button("CHANGE TABLE") {
                        returnToMenu()
                    }
                    .font(.footnote.bold())
                    .foregroundColor(.white)
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
}
