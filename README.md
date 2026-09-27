# PokerTrainer

An offline Texas Hold'em game for iPhone, designed and developed by **PARK, SEHO**. Play against one or two computer opponents, earn chips, and clear four increasingly demanding levels. No account, Wi-Fi, server, real-money betting, or trained AI model is required.

<p align="center">
  <img src="PokerTrainer/Assets.xcassets/AppIcon.appiconset/thumbnail.png" width="220" alt="PokerTrainer app icon">
</p>

## Current build

- Playable 1 vs 1 and 1 vs 2 SwiftUI tables with separate four-level campaigns; 1 vs 2 blinds increase by level and every 12 completed hands (capped at five extra increases per level).
- Standard 52-card Hold'em dealing; dealer and blind rotation; check, call, raise, fold, and all-in actions.
- Best-five-of-seven hand evaluation, kickers, ace-low straights, ties, main/side pots, and unmatched-chip refunds.
- Local, versioned save/continue after each action. In 1 vs 2, an eliminated opponent sits out until the next level; the two remaining seats play heads-up.
- On-device Monte Carlo equity estimation and rule-based opponents whose position, board-context, bet sizing, and playing personality vary by level.
- Lightweight card-dealing, showdown-flip, chip-contribution, and pot-award effects. Reduced Motion disables the effects.
- 61 default core tests pass, with two opt-in difficulty benchmarks. Both four-level campaigns have been won with random deals by directly operating an iPhone Simulator; the 1 vs 2 victory ended with both opponents out and 21,000 chips.

The UI uses chips, not money. The displayed “random-hand equity” estimates results against uniformly sampled unknown hands. It does **not** predict an opponent's actual betting range or guarantee a win.

## Why probability, not machine learning?

Monte Carlo simulation is a numerical technique, not a trained model. I did not have a sufficiently large, representative, validated poker-hand dataset to train and evaluate an ML policy. Training on an iPhone would add storage, energy, thermal, and implementation costs to an offline project without a demonstrated benefit. A local simulator plus a transparent decision policy is compact, testable, and explainable. Modern iPhones can run pre-trained ML models; this is a product- and data-quality choice, not a claim that mobile ML is impossible.

## Design

```text
SwiftUI tables and menu
    ↓
Game managers: computer decisions, cancellable equity work, local saves
    ↓
Deterministic heads-up / three-seat rule engines
    ↓
Shared deck, hand evaluator, equity estimator, opponent strategy
```

The rule engines own legal actions and chip settlement. UI animations cannot decide a winner or move chips in the underlying game. Save loading validates cards, chips, turn order, and campaign state. Each table has an independent save file inside the app's local container.

## Build and test

Open [PokerTrainer.xcodeproj](PokerTrainer.xcodeproj) in Xcode, choose the `PokerTrainer` scheme, and run it on an iPhone Simulator. Select a development team for a physical device. The minimum deployment target is iOS 26.0.

Run the core regression suite with:

```bash
swift test
```

To repeat the exploratory level comparison on the same seeded deals in both modes:

```bash
POKERTRAINER_BENCHMARK=1 swift test --filter OpponentDifficultyBenchmarkTests
```

## Limitations and next work

- Visually check animation timing and Reduced Motion on more iPhone sizes; the effects do not alter rules or saved state.
- The initial difficulty comparison uses a fixed check/call player and short equity estimates; it is not a general strength rating. Repeat with varied playing styles and production-length estimates.
- Profile performance on physical iPhones; add accessibility and hand-history polish.
- Local saves are removed when the app is uninstalled. There is no cloud synchronization.

See the [portfolio summary](docs/PORTFOLIO.md), [development log](docs/DEVELOPMENT_LOG.md), and [roadmap](docs/ROADMAP.md).

## Author

**PARK, SEHO** — independent developer and project designer.
