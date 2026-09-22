# PokerTrainer — Portfolio Summary

## Project overview

| Item | Description |
|---|---|
| Creator | PARK, SEHO |
| Type | Independent offline iOS project |
| Stack | Swift, SwiftUI, Swift Concurrency |
| Focus | Mobile development, poker rules, probability, and game-state design |
| Status | Working prototype under structured redesign |

## Goal

I created PokerTrainer to explore whether a complete poker practice experience could run locally on an iPhone. The player competes against increasingly disciplined computer opponents, making the app useful for casual play and solo practice without Wi-Fi or another person.

## What I implemented

- A complete 52-card deck and dealing model
- Best-five-of-seven poker-hand evaluation
- Hand categories, kickers, and ace-low straights
- Monte Carlo equity estimation from incomplete information
- A rule-based computer opponent using equity and pot odds
- A SwiftUI table with cards, chips, actions, and showdown results
- A simple four-level progression system
- Background calculation to avoid blocking the main interface

## Why I chose probability instead of ML

Monte Carlo simulation is not machine learning. It is a numerical method for estimating uncertain outcomes.

I chose it because the project is offline-first and I did not have a large, representative, validated dataset of poker games for training. Training a useful policy directly on an iPhone would also introduce unnecessary storage, energy, thermal, and implementation costs. By contrast, Monte Carlo simulation works directly from the known rules and cards, is compact enough for local execution, and produces results that can be reproduced and explained.

Modern iPhones can run pre-trained ML models, so this was a scope and data-quality decision rather than a claim that mobile ML is impossible. ML may become relevant later only if a suitable dataset and evaluation process demonstrate a real advantage.

## Engineering review

After finishing the first playable version, I reviewed the project instead of presenting the prototype as complete. Focused checks identified problems in turn completion, all-in responses, unmatched chips, split-pot equity, hidden-card disclosure, and asynchronous result ordering.

The central lesson was that a poker game needs an explicit state machine. Equal bets do not always mean that every player has acted, and an all-in state does not always mean that the hand can immediately proceed to showdown.

The redesign therefore separates:

- A deterministic poker engine
- Computer-opponent decisions
- Local save and restore
- SwiftUI presentation and animation

## Planned evolution

The next version will first correct and test heads-up rules. It will then add a three-player table, main and side pots, local continuation, stronger range-aware opponents, and card-and-chip animations. The final product goal is an offline campaign ending in a three-player final table and championship summary.

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
Designed and developed an offline SwiftUI Texas Hold'em prototype featuring best-five-of-seven hand evaluation, Monte Carlo equity estimation, and an explainable rule-based computer opponent. Reviewed the first implementation, reproduced state and betting defects, and created a phased redesign toward tested three-player gameplay, local persistence, stronger opponents, and state-driven animation.

## Interview summary

> PokerTrainer is an offline iPhone poker project that combines deterministic game rules with Monte Carlo equity estimation. I deliberately used a rule-based opponent instead of claiming machine learning because I did not have a suitable training dataset, and the probabilistic approach was smaller, explainable, testable, and appropriate for local execution. After completing the prototype, I reproduced several betting and concurrency issues and converted them into a structured redesign roadmap.

