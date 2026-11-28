# Alignment with PR #22419

The formal package pins SPEC, ACCEPTANCE, ANCHORLESS, SWITCH and the rule index to
`3fe7350119f2efe38cf588c145a9913bf9b3b398` (2026-11-20).

- **Unzen start.** Any caller can latch a height after the fork time and the live proposal
  cutoff. The model checks that every proposal is finalized and reads the matching hash and
  root from the checkpoint at that height. The DAO start rewrite is removed. H4 now finalizes
  the last Unzen proposal before calling `setOrigin` when no start has been written.
- **Registry.** Forfeiture and recovery exclusions use permanently issued bond IDs. A
  withdrawn bond remains issued after its slot is reused. Checkpoints take entries up through
  the last occupied slot, preserving interior empty slots.
- **Settlement.** A proof origin must be retained. A successful landing cannot lower the
  active committee snapshot. H4's recovery window explicitly requires R at or above the
  current snapshot, so its first recovered block can meet that check.
- **Rule schedule.** Both scheduling calls bind the expected generation. Stale calls are rejected.

The landing model still checks the Unzen relation for an initial frontier as a redundant
decoded consistency check. It also retains the stronger per-block commit and archive
hypotheses documented in the [#22412 alignment](alignment-22412.md). The alternative
settled-rotation ancestry witness, raw registry-root encoding, stock Comet header and import
checks, signer WAL and height-floor behavior, rolling audit restoration and switch reschedule
rehearsal remain outside the checked implementation boundary. The follow-up at `3fe735011` extends the import window to every height still within either stock
evidence age limit. It also requires verified terminal commit and gossip history lookups before
P2P opens. DATA-5.4-2 and DATA-5.4-3 remain deferred at rule level because the decoded import
uses adapter results for stock store behavior.
