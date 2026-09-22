# PokerTrainer

An offline Texas Hold'em practice game for iPhone, created by **PARK, SEHO**.

PokerTrainer is a personal SwiftUI project in which the player competes against progressively more disciplined computer opponents. The long-term goal is to create a polished local poker game for casual play and solo practice without requiring Wi-Fi, an account, or a remote server.

<p align="center">
  <img src="PokerTrainer/Assets.xcassets/AppIcon.appiconset/thumbnail.png" width="220" alt="PokerTrainer app icon">
</p>

## Current status

The repository contains a working heads-up prototype. It can deal cards, accept player actions, reveal the board, estimate equity, compare final hands, settle the pot, and advance through opponent levels.

The project is under active redesign. A technical review found several betting, all-in, tie-equity, and asynchronous-state issues that must be corrected before adding three-player gameplay and presentation effects. These findings are documented openly rather than hidden behind the prototype.

## Current features

- Native iPhone interface built with SwiftUI
- Shuffled 52-card deck
- Heads-up Texas Hold'em flow
- Check, call, raise, fold, and all-in controls
- Best-five-of-seven hand evaluation
- Ace-low straight and kicker comparison
- Monte Carlo equity estimation
- Rule-based computer opponent with four levels
- Chip stacks, pot settlement, and level progression
- No network or third-party dependency

## How the computer opponent works

PokerTrainer does not use a trained machine-learning model.

The current decision pipeline is:

```text
Known cards
    ↓
Monte Carlo simulation of unknown cards
    ↓
Estimated hand equity
    ↓
Comparison with pot odds
    ↓
Rule-based fold, check, call, or raise decision
```

The Monte Carlo component repeatedly completes the board, deals a possible opposing hand, evaluates both results, and estimates equity from the simulated outcomes. A separate decision policy uses that estimate with pot odds and controlled randomness.

### Why not machine learning or deep learning?

This was a deliberate engineering decision rather than an attempt to present a probability calculation as AI.

- The application is designed to run entirely on an iPhone without a backend.
- Training a useful poker policy would require substantial, representative, and legally usable game data.
- I did not have a sufficiently large and validated poker-hand dataset for supervised or reinforcement learning.
- On-device training would add storage, energy, thermal, and development costs that are unnecessary for this prototype.
- A Monte Carlo estimator is compact, explainable, testable, and directly suited to uncertainty in card games.
- A deterministic rule-based policy makes incorrect decisions easier to reproduce and improve.

Modern iPhones can run pre-trained Core ML models. The decision not to use ML is therefore about data quality, product scope, explainability, and offline constraints—not a claim that mobile ML is impossible. A trained model would only be justified later if the project obtains an appropriate dataset, evaluation methodology, and a clear benefit over the probabilistic approach.

## Architecture

```text
PokerTrainerApp
      │
      ▼
ContentView ───────────── SwiftUI interface and player input
      │
      ▼
PokerGameManager ──────── Current game state and prototype flow
      ├── Deck ────────── Card creation, shuffling, and dealing
      ├── Evaluator ───── Hand ranking and tie-breakers
      └── EquityCalculator
            ├── Monte Carlo equity estimation
            └── Rule-based opponent decision
```

The next architecture will separate a deterministic poker engine from opponent decisions, persistence, and animation. The engine will decide what happened; SwiftUI will only present and animate validated state transitions.

## Verified prototype issues

| Area | Finding |
|---|---|
| Turn order | A player check can advance the street before the opponent acts |
| All-in flow | A player or opponent response can be skipped |
| Pot settlement | Unmatched chips and future side pots are not handled correctly |
| Equity | A tied board currently receives full-win credit instead of split credit |
| Concurrency | Older simulations can finish after and overwrite newer results |
| Hidden information | A fold can be represented as showdown and reveal the opponent's cards |

The first implementation phase focuses on these correctness problems and permanent automated tests.

## Product direction

The target version will include:

- Correct blinds, turn order, legal actions, all-ins, and pot settlement
- Chips instead of real-money presentation
- Heads-up and player-versus-two-computer tables
- Main-pot and side-pot support
- Stronger range- and position-aware computer opponents
- Automatic local save and Continue Game support
- Card dealing, card flip, chip movement, and pot-award animations
- A final-table victory sequence and campaign restart
- Hand history and decision feedback for solo practice

See the concise [Roadmap](docs/ROADMAP.md) and [Development Log](docs/DEVELOPMENT_LOG.md).

## Project structure

```text
PokerTrainer/
├── README.md
├── docs/
│   ├── PORTFOLIO.md
│   ├── DEVELOPMENT_LOG.md
│   └── ROADMAP.md
├── PokerTrainer.xcodeproj/
└── PokerTrainer/
    ├── PokerTrainerApp.swift
    ├── ContentView.swift
    ├── PokerGameManager.swift
    ├── Card.swift
    ├── Evaluator.swift
    ├── EquityCalculator.swift
    └── Assets.xcassets/
```

## Running the project

1. Clone the repository.
2. Open `PokerTrainer.xcodeproj` in Xcode.
3. Select the `PokerTrainer` scheme.
4. Choose an iPhone simulator or connected iPhone.
5. Select your development team if physical-device signing is required.
6. Build and run.

The project currently targets iOS 26.5 and uses automatic signing with the bundle identifier `com.sehopark.PokerTrainer`.

## Technology

- Swift
- SwiftUI
- Combine observation
- Swift Concurrency
- Monte Carlo simulation
- Recursive combination generation
- Apple frameworks only

## Documentation

- [Portfolio Summary](docs/PORTFOLIO.md)
- [Development Log](docs/DEVELOPMENT_LOG.md)
- [Product Roadmap](docs/ROADMAP.md)

## Author

**PARK, SEHO**  
Independent developer and project designer

