# PokerTrainer — Development Log

This is a concise record of major decisions and verification, not a claim that every planned feature is finished.

1. **Concept and prototype.** Built an offline SwiftUI Hold'em game for solo practice and short play sessions. Replaced real-money language and “GTO AI” claims with chips and an honest description of a probabilistic, rule-based opponent.
2. **Core review.** Reproduced skipped betting responses, all-in and unmatched-chip errors, overstated tie equity, folded-card disclosure, and stale asynchronous calculations.
3. **Heads-up stabilization.** Moved betting and settlement into a deterministic engine. Added turn, card, chip, and save-state invariants with regression tests.
4. **Three-seat table.** Added circular action order, dealer/blind rotation, main and side pots, short-all-in rules, and two independently acting computer opponents.
5. **Local continuation.** Added separate atomic, versioned saves for both tables. A loaded game is checked before restoring cards, deck, actor, chips, and campaign progress.
6. **Difficulty and campaigns.** Added a context-aware opponent policy, distinct playing personalities, and four-level progression in both modes. The three-seat engine can continue with two active seats after an elimination.
7. **Extended hands-on validation.** Won the 1 vs 1 championship on an iPhone 17 Simulator. Played the 1 vs 2 table through Level 2 and into Level 3, including all-ins, folds, showdowns, elimination, two-seat continuation, save/relaunch, and app updates. This play revealed rebuy and fold-pot-display defects, which were corrected and given regression tests. A full random-deal 1 vs 2 Simulator victory remains open.
8. **Pacing review.** A long 1 vs 2 run reached hand 153 while still at Level 2 with fixed 10/20 blinds. Blinds now scale by level (10/20, 20/40, 40/80, 80/160), beginning at the next hand for an existing save.
9. **Live-equity correction.** Direct play found that the previous street's equity could remain visible while the next street was being calculated. Both tables now show a calculation state until the new estimate is ready; the three-seat table also recalculates when a fold changes the number of active players.
10. **Tournament pacing.** Within each 1 vs 2 level, blinds double after 12 and 24 completed hands, then stay capped. Older campaign saves start the new blind clock at zero; their current hand and chips remain intact.
11. **Shared-session boundary.** A later interactive Simulator session visibly reached Level 4. Because another person was operating that same Simulator during the final segment, that result is not treated as a controlled solo playthrough or a verified 1 vs 2 championship.

**Current automated verification:** 60 passing core tests and a successful iOS Simulator build. Scripted tests reach the championship in both modes; they complement but do not replace full touchscreen play, physical-device checks, or battery profiling.
