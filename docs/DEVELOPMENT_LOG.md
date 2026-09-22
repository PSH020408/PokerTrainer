# PokerTrainer — Development Log

This log summarises the project by development stage rather than recording every code edit.

## Stage 1 — Product concept

Defined an offline iPhone poker game for casual play and solo practice. The original objective was to defeat progressively more difficult computer opponents without requiring Wi-Fi or another player.

## Stage 2 — Card and hand model

- Created card, suit, and shuffled-deck types
- Implemented standard poker-hand categories
- Added kicker comparison and ace-low straight handling
- Evaluated every five-card combination from seven cards

## Stage 3 — Equity estimation

- Added Monte Carlo completion of unknown cards
- Compared simulated final hands
- Moved repeated calculation away from the main UI work
- Chose a probabilistic method because it required no training dataset or remote service

## Stage 4 — Playable SwiftUI prototype

- Added chip stacks, pot, private cards, and community cards
- Added check, call, raise, fold, and all-in controls
- Added a rule-based opponent using equity, pot odds, and level-based randomness
- Added level progression and showdown settlement

## Stage 5 — Technical review

Verified that the app builds and that the core deck and hand evaluator work. Reproduced important prototype defects:

- Check can skip the opponent's action
- All-in responses can be skipped
- Unmatched chips can enter the pot
- Split-pot equity is overstated
- Older background calculations can overwrite newer results
- Folded hands can reveal hidden cards

These findings changed the next priority from visual expansion to a tested poker state machine.

## Stage 6 — Naming and documentation

- Renamed the product to `PokerTrainer`
- Removed AI and GTO claims from the public description
- Described the opponent as rule-based and equity-informed
- Replaced real-money presentation with poker-chip terminology
- Added concise GitHub, portfolio, development, and roadmap documents

## Next stage

Build and test the deterministic heads-up engine before introducing three-player rules, persistence, stronger opponents, or animation.

