# PokerTrainer — Roadmap

The roadmap prioritises correctness before visual polish. Each phase should be completed and tested before the next one begins.

## Phase 1 — Correct heads-up rules

- Create an explicit turn and betting-round state machine
- Add dealer, small blind, and big blind positions
- Validate legal checks, calls, raises, folds, and all-ins
- Return unmatched chips correctly
- Count split-pot equity fractionally
- Keep fold and showdown results separate
- Add a permanent unit-test target

**Done when:** every tested hand preserves all cards and chips, every required player acts, and no illegal action reaches the game state.

## Phase 2 — Three-player engine

- Replace fixed player/opponent fields with a seat collection
- Add circular action order
- Support one player versus two computer opponents
- Build main pots and side pots from contribution levels
- Compare two or three eligible hands at showdown

**Done when:** multiple folds and all-ins settle correctly and the total number of chips never changes.

## Phase 3 — Local save and continue

- Save a versioned snapshot after each completed action
- Store cards, remaining deck, chip stacks, pots, positions, street, and current turn
- Add Continue Game and New Game entry points
- Recover safely from missing or invalid save data

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
