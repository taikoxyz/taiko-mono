# Etna PoS + ZK design specification

- [SPEC.md](SPEC.md): the design specification, sections 1–12 and appendices A–C.
- [ACCEPTANCE.md](ACCEPTANCE.md): the acceptance and launch checklist.

In Etna, a committee of TAIKO stakers produces blocks with stock CometBFT and
finalizes them instantly; anyone can land a proven batch on L1, and funds on L1
recognize only landed checkpoints. The target is Stage 0.

## Reading map

| Section                                                                                    | Covers                                                                           |
| ------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------- |
| [1. Positioning and security model](SPEC.md#1-positioning-and-security-model)              | Security model and trust assumptions                                             |
| [2. Components](SPEC.md#2-components)                                                      | Roles and components                                                             |
| [3. Consensus and blocks](SPEC.md#3-consensus-and-blocks)                                  | Stock CometBFT, EL integration, anchors, validity and size limits                |
| [4. Staking and committees](SPEC.md#4-staking-and-committees)                              | Registration/top-ups, exits, double-sign and DAO forfeiture, committee selection |
| [5. Data formats and DA](SPEC.md#5-data-formats-and-da)                                    | Private envelopes, public blobs and public EL reconstruction                     |
| [6. Landing and settlement](SPEC.md#6-landing-and-settlement)                              | Landing checks, two proofs, grid cuts, overlapping jobs and back-pressure        |
| [7. Forced inclusion](SPEC.md#7-forced-inclusion)                                          | Queue admission, singleton builds, legal skipping and protocol fees              |
| [8. Halts and recovery](SPEC.md#8-halts-and-recovery)                                      | Pauses, safety halts, verifier failure and DAO recovery                          |
| [9. Sync and weak subjectivity](SPEC.md#9-sync-and-weak-subjectivity)                      | L1 checkpoint trust, guarded signing and consensus-history availability          |
| [10. Startup and deployment](SPEC.md#10-startup-and-deployment)                            | Genesis, deployment constraints and upgrade boundaries                           |
| [11. Parameters](SPEC.md#11-parameters)                                                    | Parameter sources, constraints and reference values                              |
| [12. Known limitations and open items](SPEC.md#12-known-limitations-and-open-items)        | All 18 limitations and open items                                                |
| [Appendix A: Encodings](SPEC.md#appendix-a-encodings)                                      | Domains, encodings, ABI and reference examples                                   |
| [Appendix B: L1 storage layout](SPEC.md#appendix-b-l1-storage-layout)                      | Inbox and registry slots, packing and namespaces                                 |
| [Appendix C: Operating funding](SPEC.md#appendix-c-operating-funding-and-cost-assumptions) | DAO operating funding and worst-case cost assumptions                            |
| [Acceptance and launch checklist](ACCEPTANCE.md)                                           | Resource, latency and recovery acceptance, shared vectors, launch gate           |

## Key review points

- **Consensus and signing:** stock CometBFT v0.40.0 with secp256k1eth keys, a
  signing domain bound to the deployment and recovery generation, committee
  changes activated two heights after they are derived, and an external signer
  that signs only after the node authenticates the latest L1 checkpoint.
- **Settlement:** exactly two sub-proofs, at least one of them ZK. A batch proves
  the range (p,h], from its proof origin p to its terminal height h. When `land`
  executes it reads c, the latest checkpoint height, and settles only the new
  suffix (c,h]. Each grid leaf binds the height, EL hash, Comet hash and FI cursor
  of its own grid point in (p,h). Before proof verification, `land` checks the
  leaf at c (when c > p) against c's slot 285 record and that record's FI cursor
  against the current FI head; the other leaves are bound only through cutHash
  in the proofs.
- **Fees:** all L2 base fees and tips go to each block's beneficiary. Forced
  inclusion fees stay in the Inbox, and anyone may sweep its ETH balance to the
  fixed DAO treasury. Landing earns no protocol reward.
- **Staking and economic security:** delayed owner-funded top-ups reuse existing
  entries. The launch checklist derives S_MIN_TOTAL from an independent capital
  target and conservative price, while operating shortfalls trigger disclosure
  and replenishment without blocking recovery. The DAO may immediately forfeit a
  fixed fraction of remaining entry principal once and force exit; this has an
  expiry and lifetime replay flag, but no forfeiture nonce or revocation entry point.
- **Recovery:** the owner calls `recover` with the expected generation, c and
  recovery nonce, an authorization deadline, and atomic exclusion and FI-blanking
  lists. The Inbox keeps only the authorization nonce, with no recovery queue or
  stall timer; explicit invalidation and verifier-failure rollback advance it. Exclusions force exits without slashing. The settled prefix stays;
  the unsettled suffix is discarded, and the new generation starts from a fixed,
  authenticated origin. A verifier failure is not handled by `recover`: its
  settlement rollback runs in the same DAO upgrade of the Inbox and registry that
  replaces the verifier.
- **Open design and acceptance:** the Unzen switch and bridge wiring (section 12
  item 9), upgrade activation (item 10), registration admission bounds (item 14)
  and deployment values for the capital target, reference price and forfeiture rate
  (item 18) remain to be pinned before launch. The value of K and the
  proving capacity behind it (6.3, section 11) are set by the checklist's
  resource acceptance, as are the real-guest, signer, recovery and launch checks.

These points are reading aids. SPEC.md holds the validity rules, and
ACCEPTANCE.md holds the acceptance and launch requirements.
