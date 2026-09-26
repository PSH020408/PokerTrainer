# PokerTrainer — Portfolio Summary

## Project overview

| Item | Description |
|---|---|
| Creator | PARK, SEHO |
| Type | Independent offline iOS project |
| Stack | Swift, SwiftUI, Swift Concurrency |
| Focus | Mobile development, poker rules, probability, and game-state design |
| Status | Playable heads-up and one-versus-two tables with local continuation; 36 tests passing |

## Goal

I created PokerTrainer to explore whether a complete poker practice experience could run locally on an iPhone. The player competes against increasingly disciplined computer opponents, making the app useful for casual play and solo practice without Wi-Fi or another person.

## What I implemented

- A complete 52-card deck and dealing model
- Best-five-of-seven poker-hand evaluation
- Hand categories, kickers, and ace-low straights
- Monte Carlo equity estimation from incomplete information
- A rule-based computer opponent using equity and pot odds
- A SwiftUI table with cards, chips, actions, and showdown results
- A second SwiftUI table for one player and two independently acting computer opponents
- A simple four-level progression system
- Background calculation to avoid blocking the main interface
- A deterministic rules engine with explicit turns, positions, and hand outcomes
- A three-seat engine with circular turns, main pots, side pots, and eligibility
- Cancellable opponent turns, hidden-card rules, and table restart/rebuy flows in the three-player mode
- Versioned on-device saves that restore the current turn, remaining deck, chips, and cards
- A 36-test regression suite covering rules, equity, evaluation, chip conservation, and restoration

## Why I chose probability instead of ML

Monte Carlo simulation is not machine learning. It is a numerical method for estimating uncertain outcomes.

I chose it because the project is offline-first and I did not have a large, representative, validated dataset of poker games for training. Training a useful policy directly on an iPhone would also introduce unnecessary storage, energy, thermal, and implementation costs. By contrast, Monte Carlo simulation works directly from the known rules and cards, is compact enough for local execution, and produces results that can be reproduced and explained.

Modern iPhones can run pre-trained ML models, so this was a scope and data-quality decision rather than a claim that mobile ML is impossible. ML may become relevant later only if a suitable dataset and evaluation process demonstrate a real advantage.

## Engineering review

After finishing the first playable version, I reviewed the project instead of presenting the prototype as complete. Focused checks identified problems in turn completion, all-in responses, unmatched chips, split-pot equity, hidden-card disclosure, and asynchronous result ordering.

The central lesson was that a poker game needs an explicit state machine. Equal bets do not always mean that every player has acted, and an all-in state does not always mean that the hand can immediately proceed to showdown.

I then replaced the original game flow with a deterministic heads-up engine. The implementation alternates dealer and blind positions, validates actions, preserves responses to all-ins, returns unmatched chips, distinguishes folds from showdowns, rejects stale calculations, and divides tied equity correctly.

The next core iteration introduced a separate three-player engine. It rotates three positions, skips folded or all-in seats correctly, creates pots from contribution levels, prevents folded seats from winning, refunds single-contributor excess, and limits re-raises after short all-ins. Automated tests include 100 heads-up and 60 three-player chip-conservation runs.

The three-player engine is now connected to a playable SwiftUI table. I tested both computer turns, a raise response, progression to the flop, a player fold followed by the opponents' showdown, dealer rotation, an all-in result, and table restart in an iPhone 17 Pro Simulator.

I then added separate, versioned local saves for both table modes. Each valid action writes an atomic snapshot; loading validates card uniqueness, chip totals, and turn state before resuming. In the Simulator, I force-closed and reopened both modes and verified that the same cards, chips, street, and available action returned.

The architecture separates:

- A deterministic poker engine
- Computer-opponent decisions
- Local save and restore
- SwiftUI presentation, with animation planned

## Planned evolution

The next implementation step is stronger range-aware computer opponents. Later phases add card-and-chip animations and a longer three-player campaign.

## Skills demonstrated

- Swift and SwiftUI development
- Domain and state modelling
- Poker-hand comparison algorithms
- Probability estimation
- Concurrency awareness
- Technical self-review and defect reproduction
- Test and architecture planning
- Honest communication of technical scope

## Short portfolio description

**PokerTrainer — Independent iOS Project**  
Designed and developed an offline SwiftUI Texas Hold'em game with playable heads-up and one-versus-two tables, deterministic betting rules, three-player side pots, best-five-of-seven evaluation, Monte Carlo equity estimation, explainable rule-based computer opponents, and validated local save/continue. Reproduced defects in the original prototype and implemented explicit turn order, legal action validation, stale-task protection, and 36 automated regression tests.

## Interview summary

> PokerTrainer is an offline iPhone poker project with playable one-versus-one and one-versus-two tables. I use deterministic rules for betting and pot settlement, and Monte Carlo simulation to inform explainable computer decisions. I did not label this machine learning because there is no trained model or suitable training dataset. After reproducing betting and concurrency defects in the first prototype, I rebuilt the game around explicit state transitions and regression tests.
