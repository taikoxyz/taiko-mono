# Alignment with PR #22422

SPEC, ACCEPTANCE, ANCHORLESS, SWITCH and the rule index are pinned to
`6a9f66833afd34bbf218e11ce7b103a522102d6d` (2026-11-20). PR #22419's final head
`3fe7350119f2efe38cf588c145a9913bf9b3b398` and its merge commit
`f556fa94186b0ab604573e8d3a4c4d4fa835dc84` have identical Etna specification trees.

- **SignalService (ANCHORLESS sections 4 and 8).** With `usesBeaconRoots` enabled,
  only a successful zero-root read at the saving block allows the syncer to write.
  The decoded root lookup prefers saved checkpoints, including after the fork.
  A missing checkpoint falls back to a live nonzero beacon root only when enabled.
  The proofs and regressions cover checkpoint collisions, failed reads and the
  checkpoint path's uint48 bound. EIP-4788 deployment, ring-buffer behavior and
  proof decoding remain external.
- **Node trust (SYNC-9-5, SYNC-9-6a).** The generation origin authenticates the
  execution header and its EL hash. The model checks the FI cursor and requires the
  Comet hash to match above the origin. The original generation's Comet hash stays
  in the proof boundary. Observing a newer closed L1 checkpoint or generation closes
  readiness for revalidation, including recovery at the same checkpoint height.
  The order and timing of live L1 reads, signing requests waiting on a comparison,
  and the supervisor's retries remain outside the decoded event model.
- **Landing precommits (PROOF-6.2-17).** The decoded vote check already requires
  precommit type, one round, matching block hash, distinct signer keys and a strict
  quorum. The regression rejects a prevote, a different-round vote and a zero
  block identifier presented for a nonzero target. Raw BlockID part-set validation,
  sign bytes and chain-id encoding remain external. H2 still assumes a verified
  decoded commit for every block, stronger than the guest's selected-commit rule.

The evidence-pool launch gate (LIMIT-12-22) requires a bound on each node's own
pool or an engine without the evidence path and with independent vote collection.
The stock baseline keeps an empty block evidence list and uses 16 blocks and
3 minutes for the off-chain age limits. The checkpoint import authenticates the
suffix still within either limit (DATA-5.4-2). Pool behavior, this import window
and stock stores remain external, as do the execution and blob codecs and the
switch rehearsal. H4 still uses plain recovery and a single-block landing.
