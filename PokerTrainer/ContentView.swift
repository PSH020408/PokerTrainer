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
    @State private var showingCoach = false
    @State private var payoutAwards: [PotAward] = []
    @State private var payoutEvent = 0
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
            // Green felt-inspired poker table background.
            Color(red: 0.1, green: 0.35, blue: 0.18)
                .ignoresSafeArea()

            VStack {
                // Header and opponent status.
                VStack(spacing: 4) {
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
                        VStack(alignment: .leading) {
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
                                .monospacedDigit()
                            Text("You: \(gameManager.playerStack) chips")
                                .font(.subheadline)
                                .foregroundColor(.green)
                                .monospacedDigit()
                        }
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
                                DealtCardView(delay: 0.08 + Double(index) * 0.11) {
                                    FlippingCardView(
                                        card: card,
                                        faceUp: gameManager.shouldRevealOpponentCards
                                    )
                                }
                                    .id("opponent-\(gameManager.game.handNumber)-\(index)")
                            }
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
                                stack: gameManager.opponentStack,
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
                                DealtCardView(delay: 0.05 + Double(index % 3) * 0.11) {
                                    CardView(card: card)
                                }
                                    .id("board-\(gameManager.game.handNumber)-\(index)")
                            }
                        }
                    }
                    .frame(height: 70)

                    if let result = HandResultSummary.headsUp(gameManager.game) {
                        HandResultBanner(result: result)
                            .padding(.horizontal)
                    }
                }

                Spacer()

                // Player hand, live equity estimate, and action controls.
                VStack(spacing: 12) {
                    // Live estimated-equity guide.
                    VStack(alignment: .leading, spacing: 4) {
                        if !gameManager.isHandComplete {
                            HStack(spacing: 5) {
                                Text("Equity vs random hands:")
                                    .font(.footnote)
                                    .foregroundColor(.white)
                                if let equity = gameManager.myEquity {
                                    Text("\(String(format: "%.1f", equity))%")
                                        .font(.footnote.bold())
                                        .foregroundColor(equity > 50 ? .green : .red)
                                } else {
                                    Text("Calculating...")
                                        .font(.footnote)
                                        .foregroundColor(.white.opacity(0.7))
                                }
                            }
                        }
                        Text(gameManager.gameMessage)
                            .font(.caption)
                            .foregroundColor(.yellow)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
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
                    HStack(spacing: 6) {
                        ForEach(Array(gameManager.playerHand.enumerated()), id: \.offset) { index, card in
                            DealtCardView(delay: 0.28 + Double(index) * 0.11) {
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
                    }

                    if !gameManager.playerHand.isEmpty {
                        Text(playerFolded
                             ? "FOLDED · Your cards cannot win this pot"
                             : "MADE HAND: \(handInsight.madeHand)")
                            .font(.caption.bold())
                            .foregroundStyle(.yellow)
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
                    } else {
                        VStack(spacing: 7) {
                            HStack(spacing: 7) {
                                Button("FOLD") {
                                    gameManager.playerAction(.fold)
                                }
                                .buttonStyle(ActionButtonStyle(color: .gray))

                                // Show CALL when chips are required; otherwise show CHECK.
                                Button(gameManager.amountToCall > 0
                                       ? "CALL \(min(gameManager.amountToCall, gameManager.playerStack))"
                                       : "CHECK") {
                                    gameManager.playerAction(
                                        gameManager.amountToCall > 0 ? .call : .check
                                    )
                                }
                                .buttonStyle(ActionButtonStyle(color: gameManager.amountToCall > 0
                                    ? .green : .blue))

                                Button("ALL-IN") {
                                    gameManager.playerAllIn()
                                }
                                .buttonStyle(ActionButtonStyle(color: .purple))
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
                }
                .padding()
                .background(Color.black.opacity(0.5))
                .cornerRadius(16)
                .padding(.horizontal)
            }

            PotAwardEffect(
                awards: payoutAwards,
                eventID: payoutEvent,
                threeSeatTable: false
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
                  let result = HandResultSummary.headsUp(gameManager.game) else { return }
            payoutAwards = result.awards
            payoutEvent += 1
        }
        .sheet(isPresented: $showingCoach) {
            HandCoachSheet(
                holeCards: gameManager.playerHand,
                board: gameManager.communityCards,
                insight: handInsight,
                randomHandEquity: gameManager.myEquity,
                isFolded: playerFolded
            )
        }
    }

    private var playerFolded: Bool {
        gameManager.game.handOutcome?.reason == .fold
            && gameManager.game.handOutcome?.winner == .opponent
    }

    private func leaveTable() {
        gameManager.deactivate()
        returnToMenu()
    }
}

// MARK: - Reusable UI Components

struct CardView: View {
    let card: Card

    var isRed: Bool {
        card.suit == .hearts || card.suit == .diamonds
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white)
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.black.opacity(0.25), lineWidth: 1)
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 1) {
                    Text(rankString(card.rank))
                        .font(.system(size: 14, weight: .bold))
                    Text(card.suit.rawValue)
                        .font(.system(size: 11, weight: .bold))
                }
                Spacer(minLength: 0)
                Text(card.suit.rawValue)
                    .font(.system(size: 24, weight: .semibold))
                    .frame(maxWidth: .infinity)
                Spacer(minLength: 0)
            }
            .padding(4)
        }
        .foregroundColor(isRed ? .red : .black)
        .frame(width: 45, height: 65)
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
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(LinearGradient(
                    colors: [Color.blue, Color(red: 0.03, green: 0.16, blue: 0.42)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.white, lineWidth: 2)
                .padding(3)
            Image(systemName: "suit.spade.fill")
                .font(.system(size: 19))
                .foregroundStyle(.white)
        }
            .frame(width: 45, height: 65)
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

// Chips travel from a betting stack toward the pot. Pot settlement uses the
// larger table-wide PotAwardEffect. Neither animation changes engine state.
struct ChipFlowEffect: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let stack: Int
    let sourceX: CGFloat
    let sourceY: CGFloat
    @State private var flights: [ChipFlight] = []

    var body: some View {
        ZStack {
            ForEach(flights) { flight in
                ForEach(0..<3, id: \.self) { chipIndex in
                    Circle()
                        .fill(Color.yellow)
                        .frame(width: 20, height: 20)
                        .overlay { Circle().stroke(Color.orange, lineWidth: 3) }
                        .overlay {
                            Image(systemName: "suit.spade.fill")
                                .font(.system(size: 7))
                                .foregroundStyle(.black)
                        }
                        .offset(
                            x: flight.hasMoved ? 0 : sourceX + CGFloat(chipIndex - 1) * 8,
                            y: flight.hasMoved ? 0 : sourceY + CGFloat(chipIndex - 1) * 6
                        )
                        .opacity(flight.hasFaded ? 0 : 1)
                }
            }
        }
        .frame(width: 20, height: 20)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: stack) { oldValue, newValue in
            guard !reduceMotion else { return }
            if newValue < oldValue { launchFlight() }
        }
        .onChange(of: reduceMotion) { _, newValue in
            if newValue { flights.removeAll() }
        }
    }

    private func launchFlight() {
        let flight = ChipFlight(id: UUID())
        flights.append(flight)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(16))
            withAnimation(.easeInOut(duration: 0.55)) {
                if let index = flights.firstIndex(where: { $0.id == flight.id }) {
                    flights[index].hasMoved = true
                }
            }
            try? await Task.sleep(for: .milliseconds(600))
            withAnimation(.easeOut(duration: 0.2)) {
                if let index = flights.firstIndex(where: { $0.id == flight.id }) {
                    flights[index].hasFaded = true
                }
            }
            try? await Task.sleep(for: .milliseconds(220))
            flights.removeAll { $0.id == flight.id }
        }
    }
}

private struct ChipFlight: Identifiable {
    let id: UUID
    var hasMoved = false
    var hasFaded = false
}

struct ActionButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(color.opacity(configuration.isPressed ? 0.7 : 1.0))
            .cornerRadius(8)
    }
}
