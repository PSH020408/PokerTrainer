//
//  ThreePlayerCampaign.swift
//  PokerTrainer
//
//  Created by PARK, SEHO on 9/26/26.
//

import Foundation

nonisolated enum ThreePlayerCampaignEvent: Equatable, Sendable {
    case none
    case opponentDefeated(TableSeat)
    case levelCleared(Int)
    case championshipWon
}

// Each opponent is eliminated once per level. The player survives to face the
// remaining opponent heads-up; both opponents return only at the next level.
nonisolated struct ThreePlayerCampaign: Codable, Equatable, Sendable {
    static let maximumLevel = 4
    static let opponentSeats: Set<TableSeat> = [.opponentOne, .opponentTwo]

    private(set) var level = 1
    private(set) var defeatedOpponents: Set<TableSeat> = []
    private(set) var won = false
    private(set) var handsCompletedAtLevel = 0

    init(
        level: Int = 1,
        defeatedOpponents: Set<TableSeat> = [],
        won: Bool = false,
        handsCompletedAtLevel: Int = 0
    ) {
        self.level = level
        self.defeatedOpponents = defeatedOpponents
        self.won = won
        self.handsCompletedAtLevel = handsCompletedAtLevel
    }

    private enum CodingKeys: String, CodingKey {
        case level, defeatedOpponents, won, handsCompletedAtLevel
    }

    // Existing campaign saves predate the within-level blind clock.
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        level = try values.decode(Int.self, forKey: .level)
        defeatedOpponents = try values.decode(Set<TableSeat>.self, forKey: .defeatedOpponents)
        won = try values.decode(Bool.self, forKey: .won)
        handsCompletedAtLevel = try values.decodeIfPresent(
            Int.self, forKey: .handsCompletedAtLevel
        ) ?? 0
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(level, forKey: .level)
        try values.encode(defeatedOpponents, forKey: .defeatedOpponents)
        try values.encode(won, forKey: .won)
        try values.encode(handsCompletedAtLevel, forKey: .handsCompletedAtLevel)
    }

    var blindMultiplier: Int {
        // Continue escalating a long level until the remaining stacks are
        // forced into decisive pots, while keeping the multiplier bounded.
        1 << (level - 1 + min(handsCompletedAtLevel / 12, 5))
    }

    var isLevelCleared: Bool {
        defeatedOpponents == Self.opponentSeats
    }

    var isValid: Bool {
        (1...Self.maximumLevel).contains(level)
            && defeatedOpponents.isSubset(of: Self.opponentSeats)
            && (!won || (level == Self.maximumLevel && isLevelCleared))
            && handsCompletedAtLevel >= 0
    }

    mutating func recordCompletedHand(_ game: ThreePlayerGameEngine) -> ThreePlayerCampaignEvent {
        guard game.isHandComplete, !won else {
            return .none
        }
        handsCompletedAtLevel += 1
        guard game.state(for: .player).stack > 0 else { return .none }

        let newlyDefeated = Self.opponentSeats.filter {
            game.state(for: $0).stack == 0 && !defeatedOpponents.contains($0)
        }.sorted { $0.rawValue < $1.rawValue }
        guard !newlyDefeated.isEmpty else { return .none }
        defeatedOpponents.formUnion(newlyDefeated)

        if isLevelCleared {
            if level == Self.maximumLevel {
                won = true
                return .championshipWon
            }
            return .levelCleared(level + 1)
        }
        return .opponentDefeated(newlyDefeated[0])
    }

    mutating func advanceLevel() {
        guard isLevelCleared, !won, level < Self.maximumLevel else { return }
        level += 1
        defeatedOpponents.removeAll()
        handsCompletedAtLevel = 0
    }
}
