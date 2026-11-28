# Alignment with PR #22422

SPEC, ACCEPTANCE, ANCHORLESS, SWITCH and the rule index are pinned to
`994960561490b882558da7847a21a41a271350c5` (2026-11-20). PR #22419's final head
`3fe7350119f2efe38cf588c145a9913bf9b3b398` and its merge commit
`f556fa94186b0ab604573e8d3a4c4d4fa835dc84` have identical Etna specification trees.

- **SignalService (ANCHORLESS sections 4 and 8).** With `usesBeaconRoots` enabled,
  only a successful zero-root read at the saving block allows the syncer to write.
  The decoded root lookup prefers saved checkpoints, including after the fork.
  A missing checkpoint falls back to a live nonzero beacon root only when enabled.
  The proofs and regressions cover checkpoint collisions, failed reads and the
  checkpoint path's uint48 bound. EIP-4788 deployment, ring-buffer behavior and
  proof decoding remain external.
- **Node trust and signing (SYNC-9-5, SYNC-9-6a, SYNC-9-10).** The generation origin authenticates the
  execution header and its EL hash. The model checks the FI cursor and requires the
  Comet hash to match above the origin. The original generation's Comet hash stays
  in the proof boundary. Observing a newer closed L1 checkpoint or generation closes
  readiness for revalidation, including recovery at the same checkpoint height.
  Signing requires the next height after the app's durable boundary for that
  generation. Verified replay, durable import and authenticated app commits set or
  advance that boundary. The regression checks that a wrong-height request leaves
  HRS unchanged. Live read ordering, timeout handling, authenticated transports,
  the precommit gate for upgrades and stock handshake/WAL repair remain external.
- **Landing precommits (PROOF-6.2-17).** The decoded vote check already requires
  precommit type, one round, matching block hash, distinct signer keys and a strict
  quorum. The regression rejects a prevote, a different-round vote and a zero
  block identifier presented for a nonzero target. Raw BlockID part-set validation,
  sign bytes and chain-id encoding remain external. H2 still assumes a verified
  decoded commit for every block, stronger than the guest's selected-commit rule.

- **Election and ABCI updates (COMM-4.3-13, PROOF-6.2-32).** FinalizeBlock returns
  additions, changed powers and zero-power removals. The H+2 activation still
  replaces the selected snapshot when the update list is empty. A regression
  checks the first rotation after recovery with identical keys and powers and a
  later snapshot.
- **Recovery capacity (START-10-14, START-10-18).** Decoded initialization uses
  the registry's minimum stake to check `K = min(4096, floor(10^27 / minStake))`
  against the modeled Inbox capacity `F`. The acceptance and rejection boundaries
  are `K = F` and `K = F + 1`. The configuration-hash refinement, the measured
  bytecode gas bound, and fitting the actual DAO transaction within it are deployment
  obligations. H4 still uses plain recovery and a single-block landing.

LIMIT-12-22 accepts the unbounded stock evidence pool. Official upstream binaries,
listed validator peers, the 16-block and 3-minute age limits, restart cleanup and
monitoring are operating requirements. Evidence-pool behavior and import-window
authentication (DATA-5.4-2) remain external.

The 4 s EIP-4396 target (ENC-A-10a) is part of the external execution interpreter.
The Unzen readiness proposal enables both checkpoint layouts and installs the L2
SignalService. The L1 scheduling proposal follows verification of that implementation
against a finalized Unzen proof. The model starts with deployment parameters supplied
and checks the Unzen cutoff and the authenticated L2 implementation at the handoff.
It leaves proposal scheduling, postponement, proof-image rollout and rehearsals to
governance and deployment.
