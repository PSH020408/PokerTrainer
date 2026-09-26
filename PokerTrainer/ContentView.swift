//
//  ContentView.swift
//  PokerTrainer
//
//  Created by PARK, SEHO on 9/6/26.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedMode: TableMode?

    var body: some View {
        Group {
            switch selectedMode {
            case .headsUp:
                HeadsUpTableView {
                    selectedMode = nil
                }
            case .threePlayer:
                ThreePlayerTableView {
                    selectedMode = nil
                }
            case nil:
                tableSelection
            }
        }
    }

    private var tableSelection: some View {
        ZStack {
            Color(red: 0.1, green: 0.35, blue: 0.18)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "suit.spade.fill")
                    .font(.system(size: 52))
                    .foregroundColor(.yellow)
                Text("PokerTrainer")
                    .font(.largeTitle.bold())
                    .foregroundColor(.white)
                Text("Choose a local practice table")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))

                Button {
                    selectedMode = .headsUp
                } label: {
                    tableChoice(title: "1 vs 1", detail: "Progress through the heads-up campaign")
                }

                Button {
                    selectedMode = .threePlayer
                } label: {
                    tableChoice(title: "1 vs 2", detail: "Practice against two computer opponents")
                }
            }
            .padding(24)
        }
    }

    private func tableChoice(title: String, detail: String) -> some View {
        VStack(spacing: 5) {
            Text(title)
                .font(.title2.bold())
            Text(detail)
                .font(.footnote)
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(18)
        .background(Color.black.opacity(0.38))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private enum TableMode {
    case headsUp
    case threePlayer
}

private struct HeadsUpTableView: View {
    @StateObject private var gameManager = PokerGameManager()
    let returnToMenu: () -> Void

    var body: some View {
        ZStack {
            // Green felt-inspired poker table background.
            Color(red: 0.1, green: 0.35, blue: 0.18)
                .ignoresSafeArea()

            VStack {
                // Header and opponent status.
                HStack {
                    VStack(alignment: .leading) {
                        Text("PokerTrainer")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("Opponent Level: \(gameManager.opponentLevel)")
                            .font(.subheadline)
                            .foregroundColor(.yellow)
                        Text("\(gameManager.currentStreet.displayName) • Dealer: \(gameManager.dealer == .player ? "You" : "Opponent")")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.75))
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("Opponent: \(gameManager.opponentStack) chips")
                            .font(.subheadline)
                            .foregroundColor(.white)
                        Text("You: \(gameManager.playerStack) chips")
                            .font(.subheadline)
                            .foregroundColor(.green)
                    }
                }
                .padding()
                .background(Color.black.opacity(0.3))
                .cornerRadius(12)
                .padding(.horizontal)

                Spacer()

                // Computer opponent area.
                VStack {
                    Image(systemName: "cpu")
                        .font(.largeTitle)
                        .foregroundColor(gameManager.isOpponentThinking ? .orange : .white)
                    Text(gameManager.isOpponentThinking ? "Opponent is thinking..." : "Computer Opponent (Level \(gameManager.opponentLevel))")
                        .font(.caption)
                        .foregroundColor(.gray)

                    // Keep the opponent's cards hidden after folds and reveal them only at showdown.
                    HStack {
                        if gameManager.shouldRevealOpponentCards {
                            ForEach(gameManager.opponentHand, id: \.description) { card in
                                CardView(card: card)
                            }
                        } else {
                            CardBackView()
                            CardBackView()
                        }
                    }
                }

                Spacer()

                // Community cards and pot information.
                VStack(spacing: 8) {
                    Text("POT: \(gameManager.potSize) CHIPS")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.yellow)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(20)

                    HStack(spacing: 8) {
                        if gameManager.communityCards.isEmpty {
                            Text("Waiting for community cards")
                                .font(.footnote)
                                .foregroundColor(.white.opacity(0.6))
                        } else {
                            ForEach(gameManager.communityCards, id: \.description) { card in
                                CardView(card: card)
                            }
                        }
                    }
                    .frame(height: 70)
                }

                Spacer()

                // Player hand, live equity estimate, and action controls.
                VStack(spacing: 12) {
                    // Live estimated-equity guide.
                    HStack {
                        Text("Estimated Equity:")
                            .font(.footnote)
                            .foregroundColor(.white)
                        Text("\(String(format: "%.1f", gameManager.myEquity))%")
                            .font(.footnote)
                            .fontWeight(.bold)
                            .foregroundColor(gameManager.myEquity > 50 ? .green : .red)
                        Spacer()
                        Text(gameManager.gameMessage)
                            .font(.caption)
                            .foregroundColor(.yellow)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.4))
                    .cornerRadius(8)

                    // Player's two private cards.
                    HStack {
                        ForEach(gameManager.playerHand, id: \.description) { card in
                            CardView(card: card)
                        }
                    }

                    // Context-sensitive action controls.
                    if gameManager.isHandComplete || gameManager.playerHand.isEmpty {
                        Button(action: {
                            gameManager.startNewHand()
                        }) {
                            Text(gameManager.nextHandButtonTitle)
                                .font(.headline)
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.yellow)
                                .cornerRadius(12)
                        }
                        if gameManager.isHandComplete {
                            Button("CHANGE TABLE") {
                                returnToMenu()
                            }
                            .font(.footnote.bold())
                            .foregroundColor(.white)
                        }
                    } else {
                        HStack(spacing: 6) {
                            Button("FOLD") {
                                gameManager.playerAction(.fold)
                            }
                            .buttonStyle(ActionButtonStyle(color: .gray))

                            // Show CALL when chips are required; otherwise show CHECK.
                            Button(gameManager.amountToCall > 0 ? "CALL \(gameManager.amountToCall)" : "CHECK") {
                                gameManager.playerAction(gameManager.amountToCall > 0 ? .call : .check)
                            }
                            .buttonStyle(ActionButtonStyle(color: gameManager.amountToCall > 0 ? .green : .blue))

                            Button("1/2 POT") {
                                let halfPot = max(gameManager.potSize / 2, 50)
                                gameManager.playerAction(.raise(amount: halfPot))
                            }
                            .buttonStyle(ActionButtonStyle(color: .orange))
                            .disabled(!gameManager.canPlayerRaise)

                            Button("POT") {
                                let fullPot = max(gameManager.potSize, 100)
                                gameManager.playerAction(.raise(amount: fullPot))
                            }
                            .buttonStyle(ActionButtonStyle(color: .red))
                            .disabled(!gameManager.canPlayerRaise)

                            Button("ALL-IN") {
                                gameManager.playerAllIn()
                            }
                            .buttonStyle(ActionButtonStyle(color: .purple))
                        }
                        .disabled(!gameManager.canPlayerAct)
                    }
                }
                .padding()
                .background(Color.black.opacity(0.5))
                .cornerRadius(16)
                .padding(.horizontal)
            }
        }
        .onAppear {
            if gameManager.game.handNumber == 0 {
                gameManager.startNewHand()
            }
        }
    }
}

// MARK: - Reusable UI Components

struct CardView: View {
    let card: Card

    var isRed: Bool {
        card.suit == .hearts || card.suit == .diamonds
    }

    var body: some View {
        VStack {
            Text(card.suit.rawValue)
                .font(.caption)
            Text(rankString(card.rank))
                .font(.title3)
                .fontWeight(.bold)
        }
        .foregroundColor(isRed ? .red : .black)
        .frame(width: 45, height: 65)
        .background(Color.white)
        .cornerRadius(6)
        .shadow(radius: 2)
    }

    func rankString(_ rank: Int) -> String {
        switch rank {
        case 11: return "J"
        case 12: return "Q"
        case 13: return "K"
        case 14: return "A"
        default: return "\(rank)"
        }
    }
}

struct CardBackView: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color.blue)
            .frame(width: 45, height: 65)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.white, lineWidth: 2)
                    .padding(3)
            )
            .shadow(radius: 2)
    }
}

struct ActionButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(color.opacity(configuration.isPressed ? 0.7 : 1.0))
            .cornerRadius(8)
    }
}
