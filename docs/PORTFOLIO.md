# PokerTrainer — Portfolio Summary

**Creator:** PARK, SEHO

**Project:** Independent, offline iPhone poker game

**Technology:** Swift, SwiftUI, Swift Concurrency, XCTest

## Objective

I wanted to turn a small poker prototype into a local game that works without another player or an internet connection. The player faces one or two computer opponents and advances through four levels by winning chips. The project emphasizes correct Hold'em rules, clear game state, and explainable decisions rather than real-money play or a claim of “GTO AI.”

## What I built

- Separate deterministic engines for heads-up and three-seat Hold'em, including blinds, turn order, all-ins, side pots, ties, and unmatched-chip refunds.
- A best-five-of-seven evaluator and on-device Monte Carlo equity estimator.
- Four difficulty levels. A rule-based decision policy uses estimated equity, pot odds, position, board texture, pressure, bet sizing, and different opponent personalities. Later levels scale blinds and opponent stacks to resist a large carried-chip advantage.
- Two SwiftUI tables, independent campaigns, local save/continue, an always-available MENU switch, and a final championship state. In 1 vs 2, a busted opponent remains eliminated during that level.
- An in-hand coach that explains visible made hands, possible draws, upgrade paths, call price, and cautious strategy notes without pretending to know opponents' cards.
- Presentation-only card and chip effects, a visible payout to the winner, and a result banner with awarded chips and revealed winning rank; moving effects respect Reduced Motion.
- 78 default automated tests for rules, chip conservation, opponent actions, campaign progression, save restoration, and reproducible equity sampling; opt-in difficulty and long-session stress tests.

## Engineering process

The first prototype exposed betting-round, all-in, hidden-card, tie-equity, and stale-background-work defects. I separated rules from presentation, made actions explicit state transitions, and wrote regression tests before expanding features. Extended Simulator play exposed a further design flaw: a defeated opponent was automatically rebought every hand. I replaced that with tournament elimination and two-seat continuation. Live play also found an overstated fold-pot display, caused by including an uncalled all-in wager; the engine now refunds that amount before reporting the contested pot.

I verified both four-level championships by directly playing random deals in an iPhone Simulator. The 1 vs 2 run ended with both Level 4 opponents eliminated and all 21,000 chips. Separate direct-play sessions also checked two-seat continuation, save/relaunch, level transitions, and restart. A smaller iPhone Simulator revealed cramped 1 vs 1 controls, which I revised and visually rechecked with Reduced Motion. Paired-deal comparisons against three player styles exposed a narrow matchup where Level 4 was not clearly stronger than Level 3; I tightened its heads-up thin value-bet behavior without changing the multiway threshold. These controlled results do not prove general or professional-level strength, and neither tests nor playthroughs prove the app is bug-free.

On a physical iPhone 17, I directly played an earlier build for approximately 16 minutes, cleared 1 vs 2 Level 1, entered Level 2, and reached 1 vs 1 Level 1 Hand 8. Both modes restored an in-progress hand after a force-quit/relaunch, and background return also worked. In a separate later user-reported 17-minute session, the battery display stayed at 94% and almost no heat was perceived. This is not a measured zero energy draw or a full physical-device campaign. The creator's quick campaign wins led to the current balance revision, which still needs human validation.

The current rebalanced build was signed, installed, and launched on the iPhone 17. I reported no further issues after installation, but did not record a timed full-campaign run on this version.

## Why no ML model?

Monte Carlo equity is probability estimation, not machine learning. I lacked a representative, validated training dataset; training a useful policy directly on a phone would impose costs that this offline project does not justify. An explainable local policy is easier to test and improve. Pre-trained mobile ML remains technically possible if future data and evaluation show a real benefit.

## Scope and optional follow-ups

The offline solo-play portfolio milestone is feature-complete. Longer, varied human playtests of the revised campaigns and a physical-device review of animation timing would improve confidence, but are not represented as completed validation. Larger production-length difficulty samples, accessibility, hand history, and optional sound/haptics are future extensions rather than requirements for this milestone.

**Short description:** Designed and developed an offline SwiftUI poker game with 1 vs 1 and 1 vs 2 campaigns, deterministic Hold'em engines, side-pot settlement, Monte Carlo equity estimates, rule-based computer opponents, a visible-card practice coach, local save/continue, and 78 default regression tests.
