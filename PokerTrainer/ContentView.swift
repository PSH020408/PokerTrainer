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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var gameManager: PokerGameManager
    let returnToMenu: () -> Void

    init(restoring session: HeadsUpSession?, returnToMenu: @escaping () -> Void) {
        _gameManager = StateObject(wrappedValue: PokerGameManager(restoring: session))
        self.returnToMenu = returnToMenu
    }

    private var smallRaiseAmount: Int {
        max(gameManager.game.minimumRaiseAmount, max(gameManager.potSize / 2, 50))
    }

    private var largeRaiseAmount: Int {
        max(gameManager.game.minimumRaiseAmount, max(gameManager.potSize, 100))
    }

    private var dealAnimation: Animation? {
        reduceMotion ? nil : .easeOut(duration: 0.28)
    }

    private var cardTransition: AnyTransition {
        reduceMotion ? .identity : .offset(y: -20).combined(with: .opacity)
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
                            .contentTransition(.numericText())
                            .animation(dealAnimation, value: gameManager.opponentStack)
                        Text("You: \(gameManager.playerStack) chips")
                            .font(.subheadline)
                            .foregroundColor(.green)
                            .contentTransition(.numericText())
                            .animation(dealAnimation, value: gameManager.playerStack)
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
                        if gameManager.opponentHand.isEmpty {
                            CardBackView()
                            CardBackView()
                        } else {
                            ForEach(Array(gameManager.opponentHand.enumerated()), id: \.offset) { index, card in
                                FlippingCardView(card: card, faceUp: gameManager.shouldRevealOpponentCards)
                                    .id("opponent-\(gameManager.game.handNumber)-\(index)")
                                    .transition(cardTransition)
                            }
                        }
                    }
                    .animation(dealAnimation, value: gameManager.game.handNumber)
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
                                stack: gameManager.opponentStack,
                                handComplete: gameManager.isHandComplete,
                                sourceX: 0,
                                sourceY: -70
                            )
                        }

                    HStack(spacing: 8) {
                        if gameManager.communityCards.isEmpty {
                            Text("Waiting for community cards")
                                .font(.footnote)
                                .foregroundColor(.white.opacity(0.6))
                        } else {
                            ForEach(Array(gameManager.communityCards.enumerated()), id: \.offset) { index, card in
                                CardView(card: card)
                                    .id("board-\(gameManager.game.handNumber)-\(index)")
                                    .transition(cardTransition)
                            }
                        }
                    }
                    .frame(height: 70)
                    .animation(dealAnimation, value: gameManager.communityCards.count)
                    .animation(dealAnimation, value: gameManager.game.handNumber)
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
                        ForEach(Array(gameManager.playerHand.enumerated()), id: \.offset) { index, card in
                            CardView(card: card)
                                .id("player-\(gameManager.game.handNumber)-\(index)")
                                .transition(cardTransition)
                        }
                    }
                    .animation(dealAnimation, value: gameManager.game.handNumber)

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

                            Button("RAISE +\(smallRaiseAmount)") {
                                gameManager.playerAction(.raise(amount: smallRaiseAmount))
                            }
                            .buttonStyle(ActionButtonStyle(color: .orange))
                            .disabled(!gameManager.canPlayerRaise)

                            Button("RAISE +\(largeRaiseAmount)") {
                                gameManager.playerAction(.raise(amount: largeRaiseAmount))
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

// A view-only flip: the card is revealed by the engine before this animation starts.
struct FlippingCardView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let card: Card
    let faceUp: Bool
    @State private var angle: Double

    init(card: Card, faceUp: Bool) {
        self.card = card
        self.faceUp = faceUp
        _angle = State(initialValue: faceUp ? 180 : 0)
    }

    var body: some View {
        Color.clear
            .frame(width: 45, height: 65)
            .modifier(CardFlipModifier(card: card, angle: angle))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(faceUp ? cardAccessibilityLabel : "Face-down card")
            .onChange(of: faceUp) { _, newValue in
                if reduceMotion {
                    angle = newValue ? 180 : 0
                } else {
                    withAnimation(.easeInOut(duration: 0.38)) {
                        angle = newValue ? 180 : 0
                    }
                }
            }
            .onChange(of: reduceMotion) { _, newValue in
                if newValue { angle = faceUp ? 180 : 0 }
            }
    }

    private var cardAccessibilityLabel: String {
        let rank: String
        switch card.rank {
        case 11: rank = "J"
        case 12: rank = "Q"
        case 13: rank = "K"
        case 14: rank = "A"
        default: rank = "\(card.rank)"
        }
        return "\(rank) of \(card.suit.accessibilityName)"
    }
}

private struct CardFlipModifier: AnimatableModifier {
    let card: Card
    var angle: Double

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    func body(content: Content) -> some View {
        content.overlay {
            ZStack {
                CardBackView()
                    .opacity(angle < 90 ? 1 : 0)
                CardView(card: card)
                    .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                    .opacity(angle >= 90 ? 1 : 0)
            }
            .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0))
        }
    }
}

// Chips travel toward the pot when a stack falls and back to a winning stack
// after settlement. No animation writes to the rule engine or save state.
struct ChipFlowEffect: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let stack: Int
    let handComplete: Bool
    let sourceX: CGFloat
    let sourceY: CGFloat
    @State private var flights: [ChipFlight] = []

    var body: some View {
        ZStack {
            ForEach(flights) { flight in
                Circle()
                    .fill(Color.yellow)
                    .frame(width: 15, height: 15)
                    .overlay { Circle().stroke(Color.orange, lineWidth: 2) }
                    .offset(
                        x: flight.hasMoved ? (flight.towardSource ? sourceX : 0)
                            : (flight.towardSource ? 0 : sourceX),
                        y: flight.hasMoved ? (flight.towardSource ? sourceY : 0)
                            : (flight.towardSource ? 0 : sourceY)
                    )
                    .opacity(flight.hasMoved ? 0 : 1)
            }
        }
        .frame(width: 15, height: 15)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: stack) { oldValue, newValue in
            guard !reduceMotion else { return }
            if newValue < oldValue {
                launchFlight(towardSource: false)
            } else if newValue > oldValue && handComplete {
                launchFlight(towardSource: true)
            }
        }
        .onChange(of: reduceMotion) { _, newValue in
            if newValue { flights.removeAll() }
        }
    }

    private func launchFlight(towardSource: Bool) {
        let flight = ChipFlight(id: UUID(), towardSource: towardSource)
        flights.append(flight)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(16))
            withAnimation(.easeOut(duration: 0.34)) {
                if let index = flights.firstIndex(where: { $0.id == flight.id }) {
                    flights[index].hasMoved = true
                }
            }
            try? await Task.sleep(for: .milliseconds(380))
            flights.removeAll { $0.id == flight.id }
        }
    }
}

private struct ChipFlight: Identifiable {
    let id: UUID
    let towardSource: Bool
    var hasMoved = false
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
