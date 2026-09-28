# PokerTrainer — Roadmap

## Completed foundations

- [x] Heads-up rule engine, hand evaluator, equity calculation, and chip-conservation tests.
- [x] Playable 1 vs 2 table with circular turns, main/side pots, and independently acting opponents.
- [x] Versioned local save/continue for each mode.
- [x] Four-level campaigns and distinct opponent personalities with position, board, and pot-odds context.
- [x] Automated full-campaign scenarios for both modes and a random-deal 1 vs 1 Simulator championship.
- [x] Tournament-style 1 vs 2 elimination, rather than automatically rebuying a busted opponent each hand.
- [x] Level-based 1 vs 2 blinds to prevent an unchanging, slow chip structure.
- [x] Capped within-level blind increases, with backward-compatible saved campaigns.
- [x] Random-deal iPhone Simulator championships in both 1 vs 1 and 1 vs 2.
- [x] View-only card, chip, and pot-award effects with Reduced Motion support.
- [x] Reproducible, paired-deal 1 vs 1 and 1 vs 2 level benchmarks against a fixed check/call player.
- [x] Small-screen 1 vs 1 controls revised after iPhone 17e Simulator review.
- [x] Physical iPhone 17 direct-play smoke test: 1 vs 2 Level 1 cleared, Level 2 started, 1 vs 1 reached Level 1 Hand 8, and both modes restored an in-progress hand after relaunch.
- [x] MENU access during an active hand, with independent 1 vs 1 and 1 vs 2 saves preserved while switching.
- [x] Hand Coach for visible made hands, direct draws, upgrade paths, call price, and cautious strategy notes; no claim of GTO or opponent-range knowledge.
- [x] Clear winner/chip/hand-rank banner and visible pot-to-winner chip movement; folded hands are marked ineligible.
- [x] Rebalance short campaigns: less passive early opponents, level-based 1 vs 1 blinds, and later-level opponent stacks scaled to the player's accumulated chips.

## Next: measured quality

- [x] Play a random-deal 1 vs 2 campaign to the final victory screen in the iPhone Simulator.
- [x] Verify two-seat play, blind rotation, save/relaunch, level transitions, and restart across direct-play sessions.
- [x] Check both tables, card visibility, actions, and showdown on an iPhone 17e Simulator with Reduced Motion enabled; restore the setting afterward.
- [ ] Review animation timing on additional iPhone sizes.
- [x] Remove the numeric chip-count transition that caused brief overlapping digits; recheck on a physical device.
- [ ] Record and fix any reproducible defects; keep regression tests for them.
- [x] Repeat paired-deal benchmarks against passive, selective, and aggressive player policies; identify matchups that do not show a strict level ordering.
- [ ] Increase production-length benchmark sample sizes and test human opponents before claiming general strength gains.
- [ ] Measure whether the revised campaigns are appropriately challenging for several human play styles; the earlier build was cleared too quickly by the creator.

## Presentation and release quality

- [x] Animate card dealing, card flips, chip contributions, and pot awards without changing engine state.
- [ ] Complete accessibility review, optional sound/haptics, and small-screen layouts.
- [x] Add an initial in-hand practice coach for visible cards and draw possibilities.
- [ ] Add hand history, opponent-range-aware lessons, and decision reviews; current guidance is intentionally basic.
- [x] Exercise 500 hands per mode with a save/restore after every action; confirm Simulator background return during a hand.
- [x] Confirm physical-device background return and force-quit/relaunch restoration in both modes.
- [x] Record a short follow-up user observation: 12:06–12:23, displayed battery 94% to 94%, with almost no perceived heat.
- [ ] Test the updated build on a physical iPhone and quantify power/thermal behavior more precisely; the display reading is not a power trace.
- [ ] Prepare App Store screenshots, icon variants, and a short gameplay recording.

**Core invariant:** chips in stacks plus unsettled pots equal the chips at hand start; cards remain unique; a street cannot advance while a required response is pending. Passing tests reduce risk but cannot prove the app is bug-free.
