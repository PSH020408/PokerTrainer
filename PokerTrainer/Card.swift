//
//  Card.swift
//  PokerTrainer
//
//  Created by PARK, SEHO on 9/6/26.
//

import Foundation

// Standard playing-card suits (♠, ♥, ♦, ♣).
nonisolated enum Suit: String, CaseIterable, Codable, Hashable, Sendable {
    case spades = "♠", hearts = "♥", diamonds = "♦", clubs = "♣"

    var accessibilityName: String {
        switch self {
        case .spades: return "spades"
        case .hearts: return "hearts"
        case .diamonds: return "diamonds"
        case .clubs: return "clubs"
        }
    }
}

// Immutable representation of a playing card.
nonisolated struct Card: Codable, Hashable, CustomStringConvertible, Sendable {
    let suit: Suit
    let rank: Int // 2 ~ 14 (11: J, 12: Q, 13: K, 14: A)

    var description: String {
        let rankStr: String
        switch rank {
        case 11: rankStr = "J"
        case 12: rankStr = "Q"
        case 13: rankStr = "K"
        case 14: rankStr = "A"
        default: rankStr = "\(rank)"
        }
        return "\(suit.rawValue)\(rankStr)"
    }
}

// Value-type 52-card deck used for shuffling, dealing, and deterministic tests.
nonisolated struct Deck: Codable, Sendable {
    private var cards: [Card]

    init(shuffled: Bool = true) {
        cards = Self.standardCards
        if shuffled {
            cards.shuffle()
        }
    }

    // Creates a deck whose first array element is drawn first.
    init(drawOrder: [Card]) {
        cards = Array(drawOrder.reversed())
    }

    static var standardCards: [Card] {
        Suit.allCases.flatMap { suit in
            (2...14).map { rank in
                Card(suit: suit, rank: rank)
            }
        }
    }

    var remainingCount: Int {
        cards.count
    }

    var remainingCards: [Card] {
        cards
    }

    // Rebuilds and shuffles a complete deck.
    mutating func reset() {
        cards = Self.standardCards
        cards.shuffle()
    }

    // Draws one card from the top of the deck.
    mutating func draw() -> Card? {
        cards.popLast()
    }
}
