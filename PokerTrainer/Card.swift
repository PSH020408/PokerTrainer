//
//  Card.swift
//  PokerTrainer
//
//  Created by PARK, SEHO on 9/6/26.
//

import Foundation

// Standard playing-card suits (♠, ♥, ♦, ♣).
enum Suit: String, CaseIterable, Sendable {
    case spades = "♠", hearts = "♥", diamonds = "♦", clubs = "♣"
}

// Immutable representation of a playing card.
struct Card: Equatable, CustomStringConvertible, Sendable {
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

// Mutable 52-card deck used for shuffling and dealing.
nonisolated final class Deck: @unchecked Sendable {
    private var cards: [Card] = []

    init() {
        reset()
    }

    // Rebuilds and shuffles a complete deck.
    func reset() {
        cards.removeAll()
        for suit in Suit.allCases {
            for rank in 2...14 {
                cards.append(Card(suit: suit, rank: rank))
            }
        }
        cards.shuffle()
    }

    // Draws one card from the top of the deck.
    func draw() -> Card? {
        return cards.isEmpty ? nil : cards.removeLast()
    }
}
