# Etna

The Etna fork includes two designs, both in this directory:

- **Anchorless blocks**: L2 blocks carry no anchor transaction. Each block
  header commits to its L1 anchor block instead: the anchor block's execution
  state root in `parentBeaconBlockRoot` and its number in `extraData`.
- **PoS + ZK**: a committee of TAIKO stakers on L2, updated at every block,
  produces blocks with stock CometBFT and finalizes them instantly; while their
  total stake is below a threshold the DAO sets on L1, a fallback key set the DAO
  also sets there signs instead. Anyone can land a proven batch on L1, and funds
  on L1 recognize only landed checkpoints. The target is Stage 0.

| File                           | Contents                                                                                                                                                                                                                                                                                                                                                                            |
| ------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [ANCHORLESS.md](ANCHORLESS.md) | The anchorless design: header, contract changes, fork and upgrade order                                                                                                                                                                                                                                                                                                             |
| [SPEC.md](SPEC.md)             | The PoS + ZK design specification, sections 1–12 and appendices A–C                                                                                                                                                                                                                                                                                                                 |
| [SWITCH.md](SWITCH.md)         | The one-time switch from Unzen to Etna: readiness and scheduling proposals, switch day, first landing                                                                                                                                                                                                                                                                               |
| [ACCEPTANCE.md](ACCEPTANCE.md) | The acceptance and launch checklist for SPEC.md                                                                                                                                                                                                                                                                                                                                     |
| [rules/](rules/README.md)      | Stable rule references for SPEC.md, with vectors and review questions                                                                                                                                                                                                                                                                                                               |
| [CLAUDE.md](CLAUDE.md)         | Guidance for AI agents editing SPEC.md and rules/; `AGENTS.md` is a symlink to it                                                                                                                                                                                                                                                                                                   |
| [deck/](deck/)                 | A slide deck that introduces Etna to engineers who know the based design. It shows an earlier revision, with staking on L1 and committees that rotate by epoch: its switch slides still show a multisig origin written before the final Unzen proof, and other slides have the landing grid, registry displacement and the landed validator-state hash, which SPEC.md no longer has |

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

| Section                                                                                    | Covers                                                                                                                                            |
| ------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| [1. Positioning and security model](SPEC.md#1-positioning-and-security-model)              | Security model and trust assumptions                                                                                                              |
| [2. Components](SPEC.md#2-components)                                                      | Roles and components                                                                                                                              |
| [3. Consensus and blocks](SPEC.md#3-consensus-and-blocks)                                  | Stock CometBFT, EL integration, anchors, validity and size limits                                                                                 |
| [4. Staking and committees](SPEC.md#4-staking-and-committees)                              | The L2 staking contract and its seats, missed-signature penalties, per-block committee derivation with the DAO's fallback key set, DAO forfeiture |
| [5. Data formats and DA](SPEC.md#5-data-formats-and-da)                                    | Private envelopes, public blobs, authenticated EL/app snapshot sync and optional full blob replay                                                 |
| [6. Landing and settlement](SPEC.md#6-landing-and-settlement)                              | Landing checks, two proofs, per-height cuts, overlapping jobs and back-pressure                                                                   |
| [7. Forced inclusion](SPEC.md#7-forced-inclusion)                                          | Queue admission, singleton builds, legal skipping and protocol fees                                                                               |
| [8. Halts and recovery](SPEC.md#8-halts-and-recovery)                                      | Pauses, safety halts, verifier failure and DAO recovery                                                                                           |
| [9. Sync and weak subjectivity](SPEC.md#9-sync-and-weak-subjectivity)                      | L1 checkpoint trust, guarded signing and consensus-history availability                                                                           |
| [10. Startup and deployment](SPEC.md#10-startup-and-deployment)                            | Genesis, deployment constraints and protocol upgrades                                                                                             |
| [11. Parameters](SPEC.md#11-parameters)                                                    | Parameter sources, constraints and reference values                                                                                               |
| [12. Known limitations and open items](SPEC.md#12-known-limitations-and-open-items)        | All 34 limitations and open items                                                                                                                 |
| [Appendix A: Encodings](SPEC.md#appendix-a-encodings)                                      | Domains, encodings, ABI and reference examples                                                                                                    |
| [Appendix B: Storage layout](SPEC.md#appendix-b-storage-layout)                            | Inbox slots and the L2 staking storage that nodes and guests read, packing and namespaces                                                         |
| [Appendix C: Operating funding](SPEC.md#appendix-c-operating-funding-and-cost-assumptions) | DAO operating funding and worst-case cost assumptions                                                                                             |
| [Acceptance and launch checklist](ACCEPTANCE.md)                                           | Resource, latency and recovery acceptance, shared vectors, launch gate, checkpoint snapshot sync (§7)                                             |

### Key review points

- **Snapshot startup:** EL-only backends, validators and full nodes may start from authenticated checkpoint snapshots at launch or later. App nodes also install the proposer priorities from the validator state that the checkpoint header's `app_hash` commits and authenticate only a bounded window of consensus history ending at the checkpoint, without pre-checkpoint EL execution or a scan from genesis, then use stock CometBFT P2P from s+1. Validators also retain the external signer state. When consensus stores are rebuilt, the signer automatically fences the last signed height H and resumes above it after verifying a commit covering H. Same-height restart requires the bound stores and verified replay through the last durable signing decision (8.2). The import window reaches back to the latest block that carries an anchor witness and covers the recent Comet headers, commits and validator sets used to validate evidence gossip. Blocks carry zero evidence bytes; vote collectors retain conflicting votes for slashing in the L2 staking contract (3.1, 9.1). The validator state is not settled on L1: the app computes it at every height (never from stock CometBFT's historical lookup) and commits it in `app_hash`, which stock CometBFT compares at every block. Keep genesis and the current origin publicly recoverable, keep the full consensus history archived so fixed-genesis replay stays possible, and preserve complete EL/app snapshot-to-latest paths; full genesis blob replay is optional (5.3, 5.4, 6.2, 8.4, 9.1).
- **Consensus and signing:** stock CometBFT v0.40.0 with secp256k1eth keys, a
  signing domain bound to the deployment and recovery generation, and an
  external signer that signs only after the node authenticates the latest L1
  checkpoint. Every block H decides the set that signs H + 2 (4.3): the bonds
  seated in the candidate snapshot that H's block-start staking call stores,
  when their total stake reaches the Inbox's `minTotalStake`, and otherwise
  the DAO's fallback key set, each key with power 1. The origin record's
  fallback keys sign each generation's first two blocks, and a switch between
  the two sources replaces the whole set at once.
- **Anchors:** every block reads L1 through its anchor, a finalized L1 block.
  Proposers move the anchor at heights that are multiples of 1,024 and keep
  it in between while it still serves the block (3.3), so L1 → L2 messages,
  forced-inclusion entries, DAO changes and landed checkpoints reach L2 about
  once per 1,024 blocks. This is the proposer's rule, not a validity rule. The
  guests authenticate every anchor on a chain of L1 headers that ends at the
  landing's reference block. Headers are joined by parent hashes or by the
  block hashes L1 keeps in state (EIP-2935); one such link reaches back up to
  8,191 blocks (6.2).
- **Settlement:** exactly two sub-proofs, at least one of them ZK. A batch proves
  the range (p,h], from its proof origin p to its terminal height h. When `land`
  executes it reads c, the latest checkpoint height, and settles only the new
  suffix (c,h]. A landing may end at any height, and `land` carries one leaf for
  every height strictly inside (p,h); each leaf binds its height, EL hash, Comet
  hash and FI cursor. Before proof verification, `land` checks the
  leaf at c (when c > p) against c's slot 285 record and that record's FI cursor
  against the current FI head; the other leaves are bound only through cutHash
  in the proofs. The guests derive every signing set under 4.3 and check each
  block's `missBitmap` against its LastCommit. They verify commit signatures
  for h and for every block whose successor has a different signing set, which
  can be every block, with up to 128 signatures each; every other block is
  bound to those through the headers' `last_block_id` links.
- **Fees:** all L2 base fees and tips go to each block's beneficiary. Forced
  inclusion fees stay in the Inbox, and anyone may sweep its ETH balance to the
  fixed DAO treasury. Landing earns no protocol reward.
- **Staking and economic security:** stake is TAIKO bridged to L2 and held by
  `EtnaStaking`, an upgradeable L2 contract the DAO owns. A bond holds one of
  n_max ≤ 128 seats while it has no exit set and at least minStake; owner
  top-ups and exits take effect at once, and no bond is moved or removed to
  admit another. Deployment sets minStake × n_max at or above TAIKO's fixed
  supply, so a bond that meets the seat conditions finds an empty seat while L2
  holds no more than that supply (section 12, item 11). Withdrawal waits
  `withdrawalDelay` L2 blocks, at least U + 2 plus an evidence window, so that,
  except after a verifier-failure rollback, a landed checkpoint covers the last
  block a bond's seat let its key sign before the stake leaves (4.1). While
  blocks are produced, a seated bond that misses `missLimit` consecutive blocks
  loses `missSlashBps` basis points of its stake; a halt penalizes nobody (4.2).
  A miss is a precommit absent from the next block's LastCommit, whatever the
  reason: a signature that arrives too late counts like one never made
  (section 12, items 24, 31 and 33). A coalition holding 1/3 or more of the
  voting power can make members that sign miss in this sense and so turn the
  penalty on them; the DAO's response is to hand signing to the fallback key
  set (item 24, RECOV-8-20a). Bond ids are never reused, and forfeiture
  identifies an issued bond by that id alone. The launch checklist derives
  `minTotalStake` from an independent capital target and conservative price;
  below it the fallback key set signs, with no stake behind it, while funds on L1
  stay protected by the two proofs. Operating shortfalls trigger disclosure and
  replenishment without blocking recovery. Through an L1 → L2 governance
  message, the DAO may immediately forfeit a fixed fraction of a bond's
  remaining principal once and force exit; this has an expiry and lifetime
  replay flag, but no forfeiture nonce or revocation entry point.
- **Recovery:** the owner calls `recover` with the expected generation, c and
  recovery nonce, an authorization deadline, an atomic FI-blanking list and an
  optional ruleset for the new generation. For recovery, the Inbox keeps only
  the authorization nonce, with no recovery queue or stall timer; explicit
  invalidation and verifier-failure rollback advance it. The settled prefix
  stays; the unsettled suffix is discarded with the staking operations in it,
  and the new generation starts from a fixed, authenticated origin whose
  fallback key set signs its first two blocks. When a third or more of the
  candidate's power is offline, the DAO sets `minTotalStake` to 2^256 − 1, which
  forces the fallback key set, and recovers in one proposal, forfeits the
  offline bonds while the fallback key set signs and then lowers the threshold
  again; when a third or more of the fallback key set
  is offline, it replaces the keys and recovers (8). A verifier
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
  (item 18), `missLimit`, `missSlashBps` and `timeout_commit` (section 11)
  remain to be pinned
  before launch. The
  proving capacity that lets one worst-case block be proven on its own
  (section 1), including a commit of up to 128 signatures at every block
  (item 32), is established by the checklist's resource acceptance, as are the
  real-guest, signer, recovery and launch checks. Gas acceptance covers the
  staking contract's entry points with every seat occupied and the block-start
  staking call's worst case within the 30,000,000 gas its frame has.

These points are reading aids. SPEC.md holds the validity rules, and
ACCEPTANCE.md holds the acceptance and launch requirements.
