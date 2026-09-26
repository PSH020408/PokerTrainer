// swift-tools-version: 6.0
//
//  PokerTrainerCore
//
//  Created by PARK, SEHO on 9/22/26.
//

import PackageDescription

let package = Package(
    name: "PokerTrainerCore",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "PokerTrainerCore", targets: ["PokerTrainerCore"])
    ],
    targets: [
        .target(
            name: "PokerTrainerCore",
            path: "PokerTrainer",
            exclude: [
                "Assets.xcassets",
                "ContentView.swift",
                "PokerGameManager.swift",
                "ThreePlayerContentView.swift",
                "ThreePlayerGameManager.swift",
                "PokerTrainerApp.swift"
            ],
            sources: [
                "Card.swift",
                "EquityCalculator.swift",
                "Evaluator.swift",
                "MultiplayerPokerEngine.swift",
                "PokerGameEngine.swift"
            ]
        ),
        .testTarget(
            name: "PokerTrainerCoreTests",
            dependencies: ["PokerTrainerCore"],
            path: "PokerTrainerTests"
        )
    ]
)
