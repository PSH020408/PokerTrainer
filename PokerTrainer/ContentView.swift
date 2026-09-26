//
//  ContentView.swift
//  PokerTrainer
//
//  Created by PARK, SEHO on 9/6/26.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedMode: PracticeMode?
    @State private var resumingSavedGame = false
    @State private var headsUpSave: HeadsUpSession?
    @State private var threePlayerSave: ThreePlayerSession?
    @State private var saveLoadWarning: String?
    @State private var pendingNewMode: PracticeMode?
    @State private var isShowingReplaceConfirmation = false

    var body: some View {
        Group {
            switch selectedMode {
            case .headsUp:
                HeadsUpTableView(restoring: resumingSavedGame ? headsUpSave : nil) {
                    selectedMode = nil
                }
            case .threePlayer:
                ThreePlayerTableView(restoring: resumingSavedGame ? threePlayerSave : nil) {
                    selectedMode = nil
                }
            case nil:
                tableSelection
            }
        }
        .confirmationDialog(
            "Replace saved game?",
            isPresented: $isShowingReplaceConfirmation,
            titleVisibility: .visible
        ) {
            Button("Start New Game", role: .destructive) {
                if let mode = pendingNewMode {
                    openTable(mode, resume: false)
                }
                pendingNewMode = nil
            }
            Button("Cancel", role: .cancel) {
                pendingNewMode = nil
            }
        } message: {
            Text("This will replace the saved progress for this table.")
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
                Text("Your progress is saved automatically on this iPhone.")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))

                tableChoice(
                    mode: .headsUp,
                    title: "1 vs 1",
                    detail: "Heads-up campaign",
                    savedHand: headsUpSave?.game.handNumber,
                    savedStreet: headsUpSave?.game.currentStreet,
                    savedHandComplete: headsUpSave?.game.isHandComplete ?? false,
                    savedLevel: headsUpSave?.opponentLevel,
                    savedWon: headsUpSave?.campaignWon ?? false
                )
                tableChoice(
                    mode: .threePlayer,
                    title: "1 vs 2",
                    detail: "Two computer opponents",
                    savedHand: threePlayerSave?.game.handNumber,
                    savedStreet: threePlayerSave?.game.currentStreet,
                    savedHandComplete: threePlayerSave?.game.isHandComplete ?? false,
                    savedLevel: threePlayerSave?.campaign.level,
                    savedWon: threePlayerSave?.campaign.won ?? false
                )

                if let saveLoadWarning {
                    Text(saveLoadWarning)
                        .font(.caption)
                        .foregroundColor(.orange)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(24)
        }
        .onAppear(perform: refreshSaveStatus)
    }

    private func tableChoice(
        mode: PracticeMode,
        title: String,
        detail: String,
        savedHand: Int?,
        savedStreet: GameStreet?,
        savedHandComplete: Bool,
        savedLevel: Int?,
        savedWon: Bool
    ) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.title2.bold())
            Text(detail)
                .font(.footnote)
            if let savedHand, let savedStreet {
                Text(savedWon ? "Championship complete" :
                    "Level \(savedLevel ?? 1) · Hand \(savedHand) · \(savedHandComplete ? "Complete" : savedStreet.displayName)")
                    .font(.caption)
                    .foregroundColor(.yellow)

                HStack(spacing: 10) {
                    Button("CONTINUE") {
                        openTable(mode, resume: true)
                    }
                    .buttonStyle(ActionButtonStyle(color: .green))

                    Button("NEW GAME") {
                        pendingNewMode = mode
                        isShowingReplaceConfirmation = true
                    }
                    .buttonStyle(ActionButtonStyle(color: .gray))
                }
            } else {
                Button("START") {
                    openTable(mode, resume: false)
                }
                .buttonStyle(ActionButtonStyle(color: .green))
            }
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(18)
        .background(Color.black.opacity(0.38))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func openTable(_ mode: PracticeMode, resume: Bool) {
        resumingSavedGame = resume
        selectedMode = mode
    }

    private func refreshSaveStatus() {
        var warnings: [String] = []

        do {
            headsUpSave = try LocalGameStore.shared.loadHeadsUp()
        } catch {
            headsUpSave = nil
            warnings.append("1 vs 1 save unavailable")
        }

        do {
            threePlayerSave = try LocalGameStore.shared.loadThreePlayer()
        } catch {
            threePlayerSave = nil
            warnings.append("1 vs 2 save unavailable")
        }

        saveLoadWarning = warnings.isEmpty ? nil
            : warnings.joined(separator: ". ") + ". Start a new game to replace it."
    }
}

private struct HeadsUpTableView: View {
    @StateObject private var gameManager: PokerGameManager
    let returnToMenu: () -> Void

    init(restoring session: HeadsUpSession?, returnToMenu: @escaping () -> Void) {
        _gameManager = StateObject(wrappedValue: PokerGameManager(restoring: session))
        self.returnToMenu = returnToMenu
    }

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
                    Text("\(gameManager.isHandComplete ? "LAST POT" : "POT"): \(gameManager.displayedPotSize) CHIPS")
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
                        if !gameManager.isHandComplete {
                            Text("Equity vs random hands:")
                                .font(.footnote)
                                .foregroundColor(.white)
                            if let equity = gameManager.myEquity {
                                Text("\(String(format: "%.1f", equity))%")
                                    .font(.footnote)
                                    .fontWeight(.bold)
                                    .foregroundColor(equity > 50 ? .green : .red)
                            } else {
                                Text("Calculating...")
                                    .font(.footnote)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                        Spacer()
                        Text(gameManager.gameMessage)
                            .font(.caption)
                            .foregroundColor(.yellow)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.4))
                    .cornerRadius(8)

                    if let warning = gameManager.saveWarning {
                        Text(warning)
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }

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
            gameManager.activate()
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(rankString(card.rank)) of \(card.suit.accessibilityName)")
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
            .accessibilityLabel("Face-down card")
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
