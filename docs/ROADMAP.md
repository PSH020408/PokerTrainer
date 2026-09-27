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

## Next: measured quality

- [x] Play a random-deal 1 vs 2 campaign to the final victory screen in the iPhone Simulator.
- [x] Verify two-seat play, blind rotation, save/relaunch, level transitions, and restart across direct-play sessions.
- [ ] Visually review effect timing and Reduced Motion on both table layouts and small screens.
- [ ] Record and fix any reproducible defects; keep regression tests for them.
- [ ] Compare opponent levels using repeated simulated hands, not subjective labels alone.

## Presentation and release quality

- [x] Animate card dealing, card flips, chip contributions, and pot awards without changing engine state.
- [ ] Complete accessibility review, optional sound/haptics, and small-screen layouts.
- [ ] Add hand history and solo-practice feedback.
- [ ] Profile performance and battery use on a physical iPhone; test background restoration and long sessions.
- [ ] Prepare App Store screenshots, icon variants, and a short gameplay recording.

**Core invariant:** chips in stacks plus unsettled pots equal the chips at hand start; cards remain unique; a street cannot advance while a required response is pending. Passing tests reduce risk but cannot prove the app is bug-free.
