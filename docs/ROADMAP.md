# PokerTrainer — Roadmap

The roadmap prioritises correctness before visual polish. Each phase should be completed and tested before the next one begins.

## Phase 1 — Correct heads-up rules ✅

Completed on 22 September 2026 with an iPhone simulator build and 19 passing core tests.

- [x] Create an explicit turn and betting-round state machine
- [x] Add dealer, small blind, and big blind positions
- [x] Validate legal checks, calls, raises, folds, and all-ins
- [x] Return unmatched chips correctly
- [x] Count split-pot equity fractionally
- [x] Keep fold and showdown results separate
- [x] Add a permanent unit-test target

**Done when:** every tested hand preserves all cards and chips, every required player acts, and no illegal action reaches the game state.

## Phase 2 — Playable three-player table ✅

Completed on 26 September 2026 with nine new core tests and an iPhone 17 Pro Simulator gameplay run.

- [x] Replace fixed player/opponent fields with a seat collection
- [x] Add circular action order
- [x] Support one player versus two computer opponents in the playable UI
- [x] Build main pots and side pots from contribution levels
- [x] Compare two or three eligible hands at showdown

**Done when:** multiple folds and all-ins settle correctly, each computer opponent acts on its own turn, and the total number of chips never changes within a hand.

## Phase 3 — Local save and continue ✅

Completed on 26 September 2026 with eight new tests and force-close/relaunch checks in an iPhone 17 Pro Simulator.

- [x] Save a versioned snapshot after each completed action
- [x] Store cards, remaining deck, chip stacks, pots, positions, street, and current turn
- [x] Add Continue Game and New Game entry points
- [x] Recover safely from missing or invalid save data

**Done when:** force-quitting and reopening restores the same state and legal actions without a network connection.

## Phase 4 — Stronger computer opponents

- Separate difficulty from playing personality
- Add position-aware starting ranges
- Consider board texture and previous actions
- Add controlled mixed actions and improved bet sizing
- Cancel stale simulations and profile battery use

**Done when:** each level has measurable behavioural differences and every selected action is legal.

## Phase 5 — Game presentation

- Animate cards from the deck to each seat
- Flip community and showdown cards
- Move chips from players to pots and pots to winners
- Highlight the active player
- Add optional sound, haptics, reduced motion, and accessibility labels

**Done when:** interrupting an animation cannot change or corrupt the game state.

## Phase 6 — Campaign and release quality

- Add a final three-player table
- Present a championship result and restart/free-play choices
- Record hand history and practice statistics
- Test small iPhones, physical devices, long sessions, and background restoration
- Add continuous build and test checks
- Replace and verify standard, dark, and tinted app-icon variants
- Prepare screenshots and a short gameplay recording

**Done when:** a complete campaign can be played offline from a fresh install through the final victory sequence.

## Core invariants

These rules must remain true after every action:

```text
sum(player chip stacks) + sum(all pots) = total chips at hand start
```

- No card exists in more than one location
- A street cannot advance while a response is pending
- A folded player cannot win a pot
- A player cannot win a side pot for which they are ineligible
- Restoring a save produces the same state and legal actions
