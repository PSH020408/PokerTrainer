//
//  TrainingOverlays.swift
//  PokerTrainer
//
//  Created by PARK, SEHO on 9/28/26.
//

import SwiftUI

// Deal each card from the virtual deck with a short stagger. Reduced Motion
// presents the same card immediately, without moving it.
struct DealtCardView<Content: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let delay: Double
    let content: Content
    @State private var dealt = false

    init(delay: Double, @ViewBuilder content: () -> Content) {
        self.delay = delay
        self.content = content()
    }

    var body: some View {
        let isShown = dealt || reduceMotion
        content
            .opacity(isShown ? 1 : 0)
            .offset(x: isShown ? 0 : -80, y: isShown ? 0 : -45)
            .rotationEffect(.degrees(isShown ? 0 : -12))
            .scaleEffect(isShown ? 1 : 0.75)
            .task {
                if reduceMotion {
                    dealt = true
                    return
                }
                try? await Task.sleep(for: .milliseconds(Int(delay * 1_000)))
                guard !Task.isCancelled else { return }
                withAnimation(.spring(duration: 0.42, bounce: 0.15)) {
                    dealt = true
                }
            }
    }
}

struct HandCoachSheet: View {
    let holeCards: [Card]
    let board: [Card]
    let insight: HandInsight
    let randomHandEquity: Double?
    let isFolded: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Label("Hand Coach", systemImage: "exclamationmark.bubble.fill")
                    .font(.title2.bold())
                    .foregroundStyle(.yellow)

                if isFolded {
                    Text("You folded. The cards below are for review only and cannot win this pot.")
                        .font(.subheadline.bold())
                        .foregroundStyle(.orange)
                }

                HStack(spacing: 5) {
                    ForEach(Array(holeCards.enumerated()), id: \.offset) { _, card in
                        CardView(card: card)
                    }
                    if !board.isEmpty {
                        Image(systemName: "plus")
                            .foregroundStyle(.white.opacity(0.7))
                        ForEach(Array(board.enumerated()), id: \.offset) { _, card in
                            CardView(card: card)
                        }
                    }
                }
                .frame(maxWidth: .infinity)

                coachSection("YOUR HAND NOW", text: insight.madeHand)

                VStack(alignment: .leading, spacing: 7) {
                    Text("WHAT COULD DEVELOP")
                        .font(.caption.bold())
                        .foregroundStyle(.yellow)
                    ForEach(insight.possibilities, id: \.self) { possibility in
                        Text("• \(possibility)")
                            .font(.subheadline)
                            .foregroundStyle(.white)
                    }
                }

                if let potOdds = insight.potOdds {
                    coachSection("PRICE TO CALL", text: String(format: "%.1f%% pot odds", potOdds))
                } else {
                    coachSection("PRICE TO CALL", text: "No call required")
                }

                if let randomHandEquity {
                    coachSection(
                        "RANDOM-HAND EQUITY",
                        text: String(format: "%.1f%%", randomHandEquity)
                    )
                }

                coachSection(
                    "COACH TIP",
                    text: isFolded
                        ? "Review the cards, but do not treat this as an action recommendation after folding."
                        : insight.advice
                )

                Text("Training aid, not a GTO solution. Draws describe visible possibilities; equity assumes randomly sampled unknown hands, not this opponent's actual range.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(20)
        }
        .background(Color(red: 0.08, green: 0.23, blue: 0.14))
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func coachSection(_ title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.yellow)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct HandResultBanner: View {
    let result: HandResultSummary

    var body: some View {
        VStack(spacing: 4) {
            Text(result.title)
                .font(.subheadline.bold())
                .foregroundStyle(.yellow)
            ForEach(result.details, id: \.self) { detail in
                Text(detail)
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.black.opacity(0.75))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.yellow, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

// A visible pot-to-winner payout, driven by an already settled engine outcome.
// It is not involved in chip accounting or save data.
struct PotAwardEffect: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let awards: [PotAward]
    let eventID: Int
    let threeSeatTable: Bool

    @State private var activeAwards: [PotAward] = []
    @State private var travelled = false
    @State private var faded = false
    @State private var sequenceID = UUID()

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(Array(activeAwards.enumerated()), id: \.offset) { _, award in
                    ForEach(0..<3, id: \.self) { chipIndex in
                        let start = CGPoint(
                            x: geometry.size.width * 0.5 + CGFloat(chipIndex - 1) * 10,
                            y: geometry.size.height * 0.48 + CGFloat(chipIndex - 1) * 4
                        )
                        let end = destination(for: award.seat, in: geometry.size)
                        chip
                            .position(
                                x: travelled ? end.x + CGFloat(chipIndex - 1) * 12 : start.x,
                                y: travelled ? end.y + CGFloat(chipIndex - 1) * 7 : start.y
                            )
                            .opacity(faded ? 0 : 1)
                            .scaleEffect(travelled ? 0.75 : 1.2)
                    }
                    Text("+\(award.chips)")
                        .font(.caption.bold())
                        .foregroundStyle(.yellow)
                        .position(destination(for: award.seat, in: geometry.size))
                        .offset(y: -25)
                        .opacity(travelled && !faded ? 1 : 0)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: eventID) { _, _ in
            guard !reduceMotion else {
                activeAwards = []
                return
            }
            activeAwards = awards.filter { $0.chips > 0 }
            travelled = false
            faded = false
            let currentSequence = UUID()
            sequenceID = currentSequence
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(25))
                guard sequenceID == currentSequence else { return }
                withAnimation(.easeInOut(duration: 1.0)) {
                    travelled = true
                }
                try? await Task.sleep(for: .milliseconds(1_050))
                guard sequenceID == currentSequence else { return }
                withAnimation(.easeOut(duration: 0.25)) {
                    faded = true
                }
            }
        }
        .onChange(of: reduceMotion) { _, enabled in
            if enabled { activeAwards = [] }
        }
    }

    private var chip: some View {
        Circle()
            .fill(Color.yellow)
            .frame(width: 25, height: 25)
            .overlay {
                Circle().stroke(Color.orange, lineWidth: 3)
                    .padding(2)
            }
            .overlay {
                Image(systemName: "suit.spade.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.black)
            }
            .shadow(color: .black.opacity(0.5), radius: 3, y: 2)
    }

    private func destination(for seat: AwardSeat, in size: CGSize) -> CGPoint {
        switch seat {
        case .player:
            CGPoint(x: size.width * 0.5, y: size.height * 0.79)
        case .opponentOne:
            CGPoint(
                x: size.width * (threeSeatTable ? 0.27 : 0.5),
                y: size.height * 0.2
            )
        case .opponentTwo:
            CGPoint(x: size.width * 0.73, y: size.height * 0.2)
        }
    }
}
