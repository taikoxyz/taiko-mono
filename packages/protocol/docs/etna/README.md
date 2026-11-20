# Etna

The Etna fork includes two designs, both in this directory:

- **Anchorless blocks**: L2 blocks carry no anchor transaction. Each block
  header commits to its L1 anchor block instead: the anchor block's execution
  state root in `parentBeaconBlockRoot` and its number in `extraData`.
- **PoS + ZK**: a committee of TAIKO stakers produces blocks with stock CometBFT
  and finalizes them instantly; anyone can land a proven batch on L1, and funds
  on L1 recognize only landed checkpoints. The target is Stage 0.

| File                           | Contents                                                                                                                                                                                                                                                                                                                    |
| ------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [ANCHORLESS.md](ANCHORLESS.md) | The anchorless design: header, contract changes, fork and upgrade order                                                                                                                                                                                                                                                     |
| [SPEC.md](SPEC.md)             | The PoS + ZK design specification, sections 1–12 and appendices A–C                                                                                                                                                                                                                                                         |
| [SWITCH.md](SWITCH.md)         | The one-time switch from Unzen to Etna: readiness and scheduling proposals, switch day, first landing                                                                                                                                                                                                                       |
| [ACCEPTANCE.md](ACCEPTANCE.md) | The acceptance and launch checklist for SPEC.md                                                                                                                                                                                                                                                                             |
| [rules/](rules/README.md)      | Stable rule references for SPEC.md, with vectors and review questions                                                                                                                                                                                                                                                       |
| [CLAUDE.md](CLAUDE.md)         | Guidance for AI agents editing SPEC.md and rules/; `AGENTS.md` is a symlink to it                                                                                                                                                                                                                                           |
| [deck/](deck/)                 | A slide deck that introduces Etna to engineers who know the based design. It shows an earlier revision: its switch slides still show a multisig origin written before the final Unzen proof, and other slides have the landing grid, registry displacement and the landed validator-state hash, which SPEC.md no longer has |

The Etna block-production and validation rules are in
[SPEC.md section 3](SPEC.md#3-consensus-and-blocks). Its header encoding is also recorded in
[Derivation.md](../Derivation.md#pre-execution-block-header).

## Anchorless design

| Section                                                                                     | Covers                                                                  |
| ------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------- |
| [1. The anchor transaction before Etna](ANCHORLESS.md#1-the-anchor-transaction-before-etna) | What the anchor transaction does and the parts that exist only for it   |
| [2. Header](ANCHORLESS.md#2-header)                                                         | `parentBeaconBlockRoot` and `extraData` from Etna on, inherited anchors |
| [3. Recording through EIP-4788](ANCHORLESS.md#3-recording-through-eip-4788)                 | How the anchor state root is recorded on L2                             |
| [4. Bridge verification](ANCHORLESS.md#4-bridge-verification)                               | The shared `SignalService`: checkpoints, then EIP-4788 roots on L2      |
| [5. Liveness](ANCHORLESS.md#5-liveness)                                                     | Why recent roots are always available                                   |
| [6. Why the state root](ANCHORLESS.md#6-why-the-state-root-rather-than-the-block-hash)      | State root versus block hash in the header                              |
| [7. EIP-4788 and EIP-2935 on L2](ANCHORLESS.md#7-prerequisite-eip-4788-and-eip-2935-on-l2)  | Deploying the system contracts before the fork                          |
| [8. Fork and migration](ANCHORLESS.md#8-fork-and-migration)                                 | Activation, the checkpoint cutoff, checkpoints and the upgrade order    |
| [9. Changes by component](ANCHORLESS.md#9-changes-by-component)                             | Contracts, execution engines, clients, provers, relayer and other tools |
| [10. Security considerations](ANCHORLESS.md#10-security-considerations)                     | Root authentication, proof checks and the fork boundary                 |
| [11. Open questions](ANCHORLESS.md#11-open-questions)                                       | Fork scheduling and other consumers of the anchor transaction           |

## PoS + ZK design

### Reading map

| Section                                                                                    | Covers                                                                                                |
| ------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------- |
| [1. Positioning and security model](SPEC.md#1-positioning-and-security-model)              | Security model and trust assumptions                                                                  |
| [2. Components](SPEC.md#2-components)                                                      | Roles and components                                                                                  |
| [3. Consensus and blocks](SPEC.md#3-consensus-and-blocks)                                  | Stock CometBFT, EL integration, anchors, validity and size limits                                     |
| [4. Staking and committees](SPEC.md#4-staking-and-committees)                              | Registration/top-ups, exits, double-sign and DAO forfeiture, committee selection                      |
| [5. Data formats and DA](SPEC.md#5-data-formats-and-da)                                    | Private envelopes, public blobs, authenticated EL/app snapshot sync and optional full blob replay     |
| [6. Landing and settlement](SPEC.md#6-landing-and-settlement)                              | Landing checks, two proofs, per-height cuts, overlapping jobs and back-pressure                       |
| [7. Forced inclusion](SPEC.md#7-forced-inclusion)                                          | Queue admission, singleton builds, legal skipping and protocol fees                                   |
| [8. Halts and recovery](SPEC.md#8-halts-and-recovery)                                      | Pauses, safety halts, verifier failure and DAO recovery                                               |
| [9. Sync and weak subjectivity](SPEC.md#9-sync-and-weak-subjectivity)                      | L1 checkpoint trust, guarded signing and consensus-history availability                               |
| [10. Startup and deployment](SPEC.md#10-startup-and-deployment)                            | Genesis, deployment constraints and protocol upgrades                                                 |
| [11. Parameters](SPEC.md#11-parameters)                                                    | Parameter sources, constraints and reference values                                                   |
| [12. Known limitations and open items](SPEC.md#12-known-limitations-and-open-items)        | All 22 limitations and open items                                                                     |
| [Appendix A: Encodings](SPEC.md#appendix-a-encodings)                                      | Domains, encodings, ABI and reference examples                                                        |
| [Appendix B: L1 storage layout](SPEC.md#appendix-b-l1-storage-layout)                      | Inbox and registry slots, packing and namespaces                                                      |
| [Appendix C: Operating funding](SPEC.md#appendix-c-operating-funding-and-cost-assumptions) | DAO operating funding and worst-case cost assumptions                                                 |
| [Acceptance and launch checklist](ACCEPTANCE.md)                                           | Resource, latency and recovery acceptance, shared vectors, launch gate, checkpoint snapshot sync (§7) |

### Key review points

- **Snapshot startup:** EL-only backends, validators and full nodes may start from authenticated checkpoint snapshots at launch or later. App nodes also install the proposer priorities from the validator state that the checkpoint header's `app_hash` commits and authenticate only a bounded window of consensus history ending at the checkpoint, without pre-checkpoint EL execution or a scan from genesis, then use stock CometBFT P2P from s+1. Validators also retain the external signer state. When consensus stores are rebuilt, the signer automatically fences the last signed height H and resumes above it after verifying a commit covering H. Same-height restart requires the bound stores and verified replay through the last durable signing decision (8.2). The import window covers committee and anchor history and the recent Comet headers, commits and validator sets used to validate evidence gossip. Blocks carry zero evidence bytes; vote collectors retain conflicting votes for L1 slashing (3.1, 9.1). The validator state is not settled on L1: the app computes it at every height (never from stock CometBFT's historical lookup) and commits it in `app_hash`, which stock CometBFT compares at every block. Keep genesis and the current origin publicly recoverable, keep the full consensus history archived so fixed-genesis replay stays possible, and preserve complete EL/app snapshot-to-latest paths; full genesis blob replay is optional (5.3, 5.4, 6.2, 8.4, 9.1).
- **Consensus and signing:** stock CometBFT v0.40.0 with secp256k1eth keys, a
  signing domain bound to the deployment and recovery generation, committee
  changes activated two heights after they are derived, and an external signer
  that signs only after the node authenticates the latest L1 checkpoint.
- **Settlement:** exactly two sub-proofs, at least one of them ZK. A batch proves
  the range (p,h], from its proof origin p to its terminal height h. When `land`
  executes it reads c, the latest checkpoint height, and settles only the new
  suffix (c,h]. A landing may end at any height, and `land` carries one leaf for
  every height strictly inside (p,h); each leaf binds its height, EL hash, Comet
  hash and FI cursor. Before proof verification, `land` checks the
  leaf at c (when c > p) against c's slot 285 record and that record's FI cursor
  against the current FI head; the other leaves are bound only through cutHash
  in the proofs. The guests verify commit signatures for h and for the last
  block each committee signs; every other block is bound to those through the
  headers' `last_block_id` links.
- **Fees:** all L2 base fees and tips go to each block's beneficiary. Forced
  inclusion fees stay in the Inbox, and anyone may sweep its ETH balance to the
  fixed DAO treasury. Landing earns no protocol reward.
- **Staking and economic security:** delayed owner-funded top-ups reuse existing
  bonds. Registration and committee eligibility use the same minStake. Admission requires an empty slot, and no bond
  is moved or removed to admit another. Deployment sets 4096 × minStake above
  TAIKO's fixed supply, so bonds that still hold the stake they registered with
  cannot hold every slot (section 12, item 11). Bond ids are never reused, and
  forfeiture and recovery exclusions identify an issued bond by that id alone. The launch
  checklist derives S_MIN_TOTAL from an independent capital target and
  conservative price, while operating shortfalls trigger disclosure
  and replenishment without blocking recovery. The DAO may immediately forfeit a
  fixed fraction of remaining entry principal once and force exit; this has an
  expiry and lifetime replay flag, but no forfeiture nonce or revocation entry point.
- **Recovery:** the owner calls `recover` with the expected generation, c and
  recovery nonce, an authorization deadline, atomic exclusion and FI-blanking
  lists, and an optional ruleset for the new generation. For recovery, the
  Inbox keeps only the authorization nonce, with no recovery queue or stall
  timer; explicit invalidation and verifier-failure rollback advance it.
  Exclusions force exits without slashing. The settled prefix stays; the
  unsettled suffix is discarded, and the new generation starts from a fixed,
  authenticated origin. Intended membership is not reserved: registrations,
  activation, exits and punishment can change selection before the end of R,
  whose finalized snapshot nodes and signers must authenticate. A verifier
  failure is not handled by `recover`: its
  settlement rollback runs in the same DAO upgrade that replaces the verifier.
  That upgrade also makes signals cached and bridge messages left `RETRIABLE`
  since the first bad landing unusable until they are proven again; legitimate
  ones still on the settled chain then complete without paying a fee twice, and
  the L1 `SignalService` and Bridge stay paused until it executes.
- **Upgrades:** rule changes take effect at an L2 timestamp from one Inbox slot
  that only the DAO writes. Each call to schedule or cancel names the current
  recovery generation. The lead time of at least `maxAnchorAge` ensures that
  every block at or after activation sees the schedule in its anchor. Nodes and guests select each block's ruleset from its anchor
  and refuse rulesets they do not implement, so the accepted image set stays flat
  and production does not stop. Structural changes stop production at a
  scheduled time and restart through `recover`.
- **Open design and acceptance:** deployment values for the capital target,
  reference price and forfeiture rate
  (item 18) remain to be pinned before launch. The proving capacity that lets
  one worst-case block be proven on its own (section 1) is established by the
  checklist's resource acceptance, as are the real-guest, signer, recovery and
  launch checks. Full-registry gas acceptance covers both admission and later
  registry changes.

These points are reading aids. SPEC.md holds the validity rules, and
ACCEPTANCE.md holds the acceptance and launch requirements.
