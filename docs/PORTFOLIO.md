# PokerTrainer — Portfolio Summary

**Creator:** PARK, SEHO

**Project:** Independent, offline iPhone poker game

**Technology:** Swift, SwiftUI, Swift Concurrency, XCTest

## Objective

I wanted to turn a small poker prototype into a local game that works without another player or an internet connection. The player faces one or two computer opponents and advances through four levels by winning chips. The project emphasizes correct Hold'em rules, clear game state, and explainable decisions rather than real-money play or a claim of “GTO AI.”

## What I built

- Separate deterministic engines for heads-up and three-seat Hold'em, including blinds, turn order, all-ins, side pots, ties, and unmatched-chip refunds.
- A best-five-of-seven evaluator and on-device Monte Carlo equity estimator.
- Four difficulty levels. A rule-based decision policy uses estimated equity, pot odds, position, board texture, pressure, bet sizing, and different opponent personalities.
- Two SwiftUI tables, independent campaigns, local save/continue, and a final championship state. In 1 vs 2, a busted opponent remains eliminated during that level.
- 60 automated tests for rules, chip conservation, opponent actions, campaign progression, and save restoration.

## Engineering process

The first prototype exposed betting-round, all-in, hidden-card, tie-equity, and stale-background-work defects. I separated rules from presentation, made actions explicit state transitions, and wrote regression tests before expanding features. Extended Simulator play exposed a further design flaw: a defeated opponent was automatically rebought every hand. I replaced that with tournament elimination and two-seat continuation. Live play also found an overstated fold-pot display, caused by including an uncalled all-in wager; the engine now refunds that amount before reporting the contested pot.

I verified the complete 1 vs 1 championship by playing it in an iPhone Simulator. Scripted rule-engine tests clear all four levels in both modes. Random-deal 1 vs 2 play has reached Level 3 and verified elimination, two-seat continuation, save/relaunch, and level transition. I do not present it as a completed manual championship yet.

## Why no ML model?

Monte Carlo equity is probability estimation, not machine learning. I lacked a representative, validated training dataset; training a useful policy directly on a phone would impose costs that this offline project does not justify. An explainable local policy is easier to test and improve. Pre-trained mobile ML remains technically possible if future data and evaluation show a real benefit.

## Next milestone

Complete the 1 vs 2 live championship, then add lightweight card and chip animations without coupling visual timing to betting rules. Physical-device performance, accessibility, hand history, and measured difficulty are later validation targets.

**Short description:** Designed and developed an offline SwiftUI poker game with 1 vs 1 and 1 vs 2 campaigns, deterministic Hold'em engines, side-pot settlement, Monte Carlo equity estimates, rule-based computer opponents, local save/continue, and 60 regression tests.
