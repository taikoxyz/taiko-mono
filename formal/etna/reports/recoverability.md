# Etna recoverability (H4)

Authorities: main `49df560256c3f20f0868f6c6e555443c2b1fd669` (2026-11-07) for SPEC,
ACCEPTANCE, ANCHORLESS and SWITCH, as for the rest of this package.

H1–H3 are safety claims: they say that nothing bad happens. Most Etna design bugs found so far
were of another kind: permanent halts, where no landing could ever succeed again. No safety
claim catches those. H4, `Recoverability`, is the fourth headline claim and is aimed at them:
from every reachable state, under named premises and hypotheses, there is a way back to an
accepted landing. It is proved in Lean with no new axioms.

This report says what H4 claims, how the proof reaches a landing, what each premise and
hypothesis assumes and who must make it true, a trap, reachable in the model, that one
hypothesis excludes, one change to the model that the proof forced, and what H4 does not say.

Terms used below:

- **Landing** (`land`): the L1 call that settles a batch of L2 blocks with two accepted proofs
  and moves the **checkpoint** c, the height of the last settled L2 block.
- **Start** S: the L2 height Etna starts from. On a new network S = 0. On a **switching
  network**, which takes over from the existing (Unzen) rollup, S is the last Unzen block,
  written by `setOrigin`.
- **Grid**: landings end only at heights h with h − S a multiple of K, the current grid size
  (SPEC 6.1). A height is **on the grid** when this holds.
- **Governance recovery** (`recover`, SPEC 8): a DAO call that starts a new **generation**
  from the current checkpoint c, reselects the committee at the L1 block R where it executes,
  and discards unsettled blocks above c. A **plain recovery** has no exclusions, blanks no
  forced-inclusion entry and makes no structural upgrade. A **structural upgrade** is a
  recovery that also installs new parameters, such as a new K (SPEC 10.1).
- **Verifier-failure rollback** (`rollback`, RECOV-8-24 to 8-34): a DAO Inbox upgrade that
  restores the checkpoint written by the last trusted landing after a bad proof was accepted.

## Where it lives

| What                       | Lean                                                                                                                                                     |
| -------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Claim                      | `Recoverability`, `RecoverableAt`, `RecoveryPremises`, `LiveAt` in `EtnaStatements/Current.lean`                                                         |
| Vocabulary                 | `CallTrace`, `RecoveryCall`, `RecoveryTrace`, `ExecutionLive`, `RulesetLive`, `CommitteeLive`, `WindowBound` in `EtnaModel/CurrentRecovery.lean`         |
| Proof                      | `Recovery.prepare` (L1 calls), `Recovery.segment` (L2 blocks), `Recovery.recoverable` (certificate and landing) in `EtnaProofs/CurrentRecovery*.lean`    |
| Headlines                  | `Headlines.recoverability`, `Headlines.deployed_recoverability` and the four-part `Headlines.claims` in `EtnaProofs/Headline/Current.lean`               |
| Joint witness              | `RecoveryNonVacuity.all_premises_satisfiable` and `live_recovers` in `EtnaWitnesses/NonVacuity/CurrentRecovery.lean`                                     |
| Trap                       | `Recovery.offgrid_no_landing` in `EtnaProofs/CurrentRecoveryTrap.lean`; `RollbackGridTrap.rollback_grid_trap` in `EtnaWitnesses/Traps/RollbackGrid.lean` |
| Statement and audit checks | `tests/CurrentRecovery.lean`, `CurrentRecoveryProof.lean`, `CurrentRecoveryTrap.lean`, `CurrentRecoveryWitness.lean`, `tests/test_current_recovery.py`   |

## The claim

```lean
def RecoverableAt (env : Environment) (w : World) : Prop :=
  ∃ u a t, RecoveryTrace env w u ∧ land env u a = some t ∧
    (w.everLanded = true → w.inbox.checkpoint.height < t.inbox.checkpoint.height)

def Recoverability : Prop :=
  ∀ env registry, RecoveryPremises env registry → ∀ w,
    Trace env (empty env registry) w → w.initialized = true → LiveAt env w →
    RecoverableAt env w
```

In words: take any environment and fresh registry that meet `RecoveryPremises`, and any state
w that a fresh deployment can reach, whose Inbox is initialized and that meets `LiveAt`. Then
some sequence of calls leads from w to a state u where `land` accepts a landing. If anything
had landed before w, the new checkpoint is above w's.

`RecoveryTrace` fixes which calls that sequence may use. Each step is one modelled call. Every
call is allowed except `rollback`, and `recover` is allowed only as a plain recovery: no
exclusions, an empty forced-inclusion blanking list and no upgrade. The claim itself therefore
keeps to the DAO's call-level limits: no rollback, no exclusions, and no blanking of provable
forced-inclusion entries (RECOV-8-45).

Two parts of the conclusion need explaining.

- **No rollback.** A rollback rewinds settled checkpoints. The spec allows one only after a
  verifier failure, and then only to the last trusted landing (RECOV-8-28). If the path could
  use one, the claim could be met by rewinding the settled prefix, which RECOV-8-58 forbids.
- **"Above the starting checkpoint" only when something has landed.** `setOrigin` accepts any
  start height, so a reachable state can hold a wrong start far above the true last Unzen
  block. The only way out is `correctStart` (the DAO's start rewrite, START-10-5c), which
  lowers the checkpoint to the true block, so no landing from there ends above the starting
  checkpoint. `correctStart` is only possible while nothing has landed, so no settled
  checkpoint is lost.

The state after the landing is again reachable. Wherever `LiveAt` holds again, H4 applies
again, so landings can resume again and again.

`Headlines.deployed_recoverability` gives the same conclusion for an actual history of raw DAO
upgrades, under the same per-upgrade authorization that `deployed_claims` uses for H1–H3.

What the proof builds and what it takes from premises:

- **Built:** every L1 call; K L2 blocks, each valid under the model's block-validity rules
  (`Blocks.Valid`), with their committee votes; the batch certificate; and the landing
  checks.
- **Supplied by hypotheses, existentially:** each block's execution header and hashes (the
  `ruleset` hypothesis), the online validators' signatures (`window`) and the blob list
  (`payloadLive`). The proof chooses inputs; these say that execution, signing and data
  availability then produce a result. No EL, signer or DA implementation is modelled.
- **Assumed:** the two accepted proofs. Proof completeness (MODEL-1-1/1-2) is the premise
  `proofComplete`, so it is assumed, not shown.

H4 rests on no honesty or vote-attribution assumption. A test checks that its statement does
not depend on `Premises`, `Locking.HonestRules`, `Locking.Minority`,
`ProtocolFinality.HonestExecutions` or `ProtocolFinality.VoteAttribution`.

## The path

From w, the proof builds these steps in order. The owner is the DAO.

1. **L1 time.** Advance L1 to the block R that the `window` hypothesis names.
2. **Start, on a switching network only.**

   - If no start is written, the origin writer calls `setOrigin` with the Unzen lane's final
     header.
   - If the written start differs from that header and nothing has landed, the owner calls
     `correctStart` with it.
   - If the Unzen lane has not finalized its last proposal, anyone calls `unzenProve` with the
     proof that the `unzen` hypothesis supplies, so the first-landing check (LAND-6.1-8a)
     passes.

   Once something has landed, H1's first-landing fence already shows that the start is the
   Unzen lane's final header.

3. **Image and verifier.** The owner registers an image that implements every ruleset the
   schedule will select (`image`) and selects the verifier version that `proofComplete` names
   (`verifier`).
4. **Recovery.** The owner calls `recover` at R with the current generation, checkpoint c and
   nonce, `validUntil` set to R's time, no exclusions, an empty blanking list and no upgrade.
   It keeps the rule schedule (`rules` = 0) when the current rulesets are live, and otherwise
   installs ruleset nextRules + 1.
5. **Close R.** Advance L1 to R + 2, so the model's L1 snapshots at R and R + 1 are closed.
6. **Blocks.** Build K blocks at heights c + 1 to c + K on c's header, which H1 shows is
   retained and hash-bound (on a switching network at c = S, the Unzen final header with
   Etna's zeroed fields).
   - Every block anchors at R. Block timestamps are max(parent + 1, R's time), so block i is
     i − 1 seconds past its anchor.
   - Every committee in the segment is elected at R, including at an epoch switch inside it,
     because every anchor and the generation's origin block are R. Each block commits in
     round 0 with votes from online keys holding more than 2/3 of the power.
   - Forced inclusion: the queue head is included as the first transaction when it is
     canonical and executes at position zero. When it is due and is not canonical, or its
     single-transaction trial completes empty, it is skipped. Otherwise the block waits.
   - Each block's execution header comes from the `ruleset` hypothesis.
7. **Landing.** The segment's statement is certified at L1 reference R + 1, with the archive
   rooted at c's header and no earlier headers. `proofComplete` gives two accepted proofs and
   `payloadLive` a blob list, so `land` accepts the landing from c to c + K.

The path never calls `rollback`, `scheduleRules` or `scheduleStop`. It needs no rollback
because `VerifierSound`, one of H1's premises, makes every landed checkpoint genuine, so a
recovery from the current c suffices. This is also why `RecoveryPremises` extends
`FundPremises`: the path uses H1's conclusion that c's header is retained and hash-bound.

## Premises

`RecoveryPremises` is H1's five fields (`FundPremises`, see the README) plus five more:

| Field                   | What it assumes                                                                                                                                                                                                                                                                                                                                                                                                                                  | Spec                                                                                  | Who must make it true                                                                                                               |
| ----------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| `recoveryClock`         | L1 time strictly increases with block number. The same fact as `currentClock`                                                                                                                                                                                                                                                                                                                                                                    | Ethereum L1 behaviour                                                                 | Ethereum L1                                                                                                                         |
| `recoveryCatalogueHash` | Catalogued EL transaction bytes hash to the environment's transaction hash. The same fact as `currentCatalogueHash`                                                                                                                                                                                                                                                                                                                              | FI-7.1-2                                                                              | Hash function; EL catalogue                                                                                                         |
| `proofComplete`         | One verifier version accepts, for every statement an image certifies, two proofs of that image, at least one of them ZK                                                                                                                                                                                                                                                                                                                          | MODEL-1-1, MODEL-1-2                                                                  | Etna zkVM/TEE guests and provers, within their resource limits; the DAO's verifier choice                                           |
| `payloadLive`           | Up to six blocks of at most 124,000 bytes each fit in one to six blobs that the payload check accepts                                                                                                                                                                                                                                                                                                                                            | 3.4 size bound, 5.2, 6.3                                                              | Blob encoding and Ethereum data availability                                                                                        |
| `unzenStart`            | On a switching network, every header that a valid proof of the Unzen Inbox's final proposal authenticates is a usable Etna start: nonzero height, hash and state root; room for six more heights below 2^48; a state root that passes the start-implementation check; and a hash-bound start header with Etna's zeroed fields. `unzenProve` is permissionless, so any valid final proof may land first; this is why the premise covers every one | LIMIT-12-9, START-10-5, START-10-5a, LAND-6.1-8a, PROOF-6.2-46a, PARAM-11-12a, SWITCH | The switching deployment, which puts the Etna `Anchor` implementation in place on L2 before S (SWITCH.md); the existing Unzen guest |

The first two repeat fields of `Premises`, so that each headline names exactly what it rests
on. The audit requires H4's proof to read every field of `RecoveryPremises`.

## Per-state hypotheses

`LiveAt` holds eight conditions on the starting state w, not on the environment. The audit
requires H4's proof to read each of them.

| Field        | What it assumes about w                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   | Spec                                                                      | Who must make it true                                                                                                                                     |
| ------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `grid`       | Once a start is written, c is on the current grid                                                                                                                                                                                                                                                                                                                                                                                                                                                         | 6.1 (landings end at grid points), BATCH-6.3-1, RECOV-8.3-3a              | Breaks after a verifier-failure rollback across a K change. In the spec only a structural recovery, which H4's path does not use, gets out (next section) |
| `generation` | generation + 2 < 2^48 (the path may run both `correctStart` and `recover`)                                                                                                                                                                                                                                                                                                                                                                                                                                | RECOV-8-47                                                                | Counter headroom; no realistic deployment exhausts it                                                                                                     |
| `nonce`      | recoveryNonce + 1 < 2^256                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 | RECOV-8.3-11                                                              | Counter headroom                                                                                                                                          |
| `rules`      | nextRules + 1 < 2^48                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      | RECOV-8-47a, appendix A's `recover(…, uint48 rules)`, STOR-B-15a          | Counter headroom                                                                                                                                          |
| `height`     | c + K < 2^48                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              | 6.1 land (48-bit heights)                                                 | Height headroom                                                                                                                                           |
| `window`     | Some later L1 block R, with room in 48 bits, whose time is more than K seconds past each of: the current L1 time plus the largest `maxAnchorAge` of any generation so far, `forkTime`, and the genesis timestamp. At R, the election over the registry succeeds, and a set of online keys that can sign every vote holds more than 2/3 of the elected power (`CommitteeLive`)                                                                                                                             | 3.4 rule 7 (anchor age), START-10-5a, 4.3, RECOV-8-17 to 8-21, LIMIT-12-6 | Ethereum L1; the deployer, by picking a genesis timestamp and `forkTime` that L1 reaches; validators online and signing; enough eligible stake            |
| `ruleset`    | Either the active and next rulesets are live and one image implements both, or ruleset nextRules + 1 is live and some image implements it. A ruleset is live (`ExecutionLive`) when, for every parent header and every FI cursor, timestamp and anchor a block producer picks, its EL accepts some hash-bound child with an empty transaction list, and every canonical forced transaction of at most 8,192 bytes either executes as the only transaction or its single-transaction trial completes empty | MODEL-1-1 (EL side), 7.2 trial, START-10.1, LIMIT-12-21                   | The ruleset's EL and guest images; the DAO and validators for rule upgrades                                                                               |
| `unzen`      | On a switching network, the Unzen lane has finalized its last proposal, or a valid proof of that proposal, linked to the lane's last finalized hash, exists from the current lane state                                                                                                                                                                                                                                                                                                                   | LIMIT-12-9, LAND-6.1-8a                                                   | Unzen provers and the existing Unzen guest                                                                                                                |

Why `window` has those three bounds: the batch parent's timestamp is bounded by its anchor's
L1 time plus that generation's `maxAnchorAge` (for c above S), by `forkTime` (a switching
start) or by the genesis timestamp (a new network at S = 0). R must be late enough that all K
new blocks, anchored at R, keep their timestamps after the parent and within the anchor-age
limit. `WindowBound` takes all three bounds on every network, whichever case applies.

Why `grid` is needed: by their own checks, `land` and `recover` keep c on the grid, and the
start writes set c = S. The model has no separate theorem that the condition holds on every
history, and the next section shows a reachable state where it fails.

## The rollback grid trap

After a structural recovery changes K, a verifier-failure rollback can restore a checkpoint
that is off the new grid. In the model, no landing ever succeeds from there without another
rollback. In the spec, a structural recovery gets out; only plain recoveries, the only kind
H4's path uses, stay blocked. So the trap is a divergence between the model and the spec, and
the reason H4 keeps the `grid` hypothesis.

**The trace** (`RollbackGridTrap.rollback_grid_trap`, a new network with S = 0):

1. K = 2. Register a bond, initialize the Inbox, register an image, and land 0 → 2, 2 → 4
   and 4 → 6.
2. The owner schedules a planned stop on grid 6, a multiple of both the old and the new K as
   START-10.1-14e asks, and L1 passes the stop time.
3. The owner runs a structural recovery at c = 6 that changes K to 3. 6 is on both grids,
   so `recover` accepts it.
4. A verifier failure is discovered. The owner rolls back to the landing at height 2, as
   RECOV-8-28 requires if 2 → 4 was the first bad landing. Generation 1 started at 6, above
   the restored c, so no landing can succeed in it (RECOV-8-33).
5. Now c = 2 and K = 3. 2 − 0 is not a multiple of 3, so c is off the grid.

**Why nothing lands again in the model** (`Recovery.offgrid_no_landing`). From a landed,
started state whose c is off the current grid, no sequence of calls without `rollback`
reaches a state where `land` accepts. That class of sequences allows every other call,
including exclusions, blanking, structural upgrades, `scheduleStop` and `scheduleRules`, so
it is wider than H4's.

- `land` needs c on the current grid.
- A plain `recover` needs c on the current grid (RECOV-8.3-3a).
- The model's structural `recover` also needs a planned stop in effect at c, with c − S a
  multiple of its `stopGrid`. `scheduleStop` accepts only a `stopGrid` that is a positive
  multiple of the current K (START-10.1-5b), and no multiple of 3 divides 2.
- Every other call either fails or leaves c and K unchanged and keeps any scheduled
  `stopGrid` a multiple of K. The start is frozen once something has landed.

**Where the model is stricter than the spec.** The model encodes the main procedure of
START-10.1-14e (schedule a stop, let production end at a grid point, settle it, then recover
from it) as checks inside `recover`'s upgrade branch. SPEC 8.3 lists `recover`'s
execution-time checks, and its only grid check, RECOV-8.3-3a, uses the new K after a
structural upgrade that changes it; it has no planned-stop check. START-10.1-14e also has a
fallback for a stop point that cannot settle: recovery runs from the last settled checkpoint
below it (vector 14e.k, accepted). So in the spec the trapped state has an exit:

1. Schedule a stop with `stopGrid` 6, a multiple of both the current K = 3 and the new K = 2.
2. Generation 1 can never settle its stop point (RECOV-8-33), so the 14e.k fallback applies.
3. One DAO transaction installs K = 2 and calls `recover` with `expectedC` = 2 and `rules` =
   nextRules + 1. RECOV-8.3-3a passes, because 2 − 0 is a multiple of 2.

That is the new governance recovery from the restored c that RECOV-8-34 requires, done as a
structural recovery.

**Why H4 still needs `grid`.** H4's path uses only plain recoveries (`RecoveryCall`). A plain
recovery keeps K, so RECOV-8.3-3a rejects it while c is off the current grid, in the spec as
in the model. From the trapped state no path of H4's class lands in either. `LiveAt.grid`
excludes the state; it is the narrowest condition that does.

**The rollback target rule.** In the model, `rollback` accepts any retained landing record at
or below c. A second rollback to the start record (c = 0, on every grid) escapes: the witness
then runs a plain recovery at c = 0 and lands 0 → 3. The spec forbids that escape. RECOV-8-28
fixes the target as the last trusted landing, here height 2, and RECOV-8-58 forbids rewinding
the settled prefix. So the trap is stated over continuations without rollback.

**What the witness shows.** Its environment's verifier accepts every proof. That is the
verifier-failure scenario that the rollback exists for, and that environment meets no premise
record. So the witness shows that the trapped state is reachable in the model. It does not
show that a deployment meeting H4's premises reaches it.

**Options.** Neither is taken here.

- Relax the model's upgrade branch of `recover` to match SPEC 8.3 and the 14e.k fallback.
  `recover` is part of H1–H3's statements, so this changes their review surface and is the
  project owner's call. The trap would then be escapable by a structural recovery, and the
  trap theorem would have to be restated over plain recoveries; H4 would still need `grid`.
- At most, a spec clarification: after a rollback across a K change, the recovery that
  RECOV-8-34 requires must be structural and install a K whose grid holds the restored c.

## A model change the proof forced

The proof needs every certificate's readiness check to pass, and that check needs
`genesisCutoff` to be at most the generation's origin L1 block. The model's `recover` used to
let a structural upgrade install any `genesisCutoff`. A reachable upgrade could then set a
cutoff above every later L1 block, and no landing would be accepted again.

The spec does not allow this. `genesisCutoff` is set once at Inbox initialization
(PARAM-11-4, START-10-2) and stored in slot 279 (STOR-B-5). START-10.1-2a puts generation 0's
genesis in the deployment core, which only a migration to a new Inbox may change.

`recover`'s upgrade branch now also requires the new parameters to keep the stored cutoff
(`parameters.genesisCutoff = w.inbox.genesisCutoff`), so a structural upgrade can change K and
the other parameters but never the genesis cutoff. `recover` is part of
H1–H3's statements, so this narrows the machine they describe. The removed behaviour is one
the spec forbids. The review-surface lock records the change to `recover`.

## Deployment-shaped conditions and known limitations

Some hypotheses are not protocol properties but duties of a deployment or of other parties.
They get no Lean counterexample. For each, here is who must make it true.

- **Genesis timestamp and `forkTime`.** On every network, `window` needs an L1 block, within
  48-bit block numbers, more than K seconds past both the genesis header's timestamp and
  `ETNA_FORK_TIME`. The deployer must set neither far in the future. On a switching network
  `setOrigin` also requires L1 time to reach `ETNA_FORK_TIME` (START-10-5a). PARAM-11-12a
  makes `ETNA_FORK_TIME` zero on a new network; a new network that set it far in the future
  would fail `window` too. A time L1 never reaches is a failed deployment, not a protocol
  trap.
- **The Unzen lane's final proposal is provable** (`LiveAt.unzen`). Unzen provers must be
  able to prove it. LIMIT-12-9 says that if they never can, for example because of a bug in
  the Unzen guest image, Etna cannot land until the DAO trusts a fixed image in the Unzen
  verifier. That DAO step is not modelled, so this is a hypothesis.
- **Every valid final Unzen header is a usable Etna start** (`unzenStart`). The switching
  deployment must put the Etna `Anchor` implementation in place on L2 before S, which the
  guest checks at S (PROOF-6.2-46a, PARAM-11-12a, SWITCH.md), and the existing Unzen guest
  must authenticate real headers with nonzero fields.
- **LIMIT-12-6, empty committee.** Recovery cannot create a quorum from nothing.
  `CommitteeLive` assumes that the election at R succeeds and that online keys hold more than
  2/3 of its power. Eligible stake must exist and its validators must be online.
- **LIMIT-12-9, start written by a multisig.** A wrong start stops Etna until the DAO
  rewrites it. The path does this with `correctStart` while nothing has landed; the
  final-proof part is the `unzen` hypothesis above.
- **LIMIT-12-21, upgrades depend on the DAO and validators.** A defective ruleset that has
  taken effect is replaced by recovery's `rules`. The path does this when the current
  rulesets are not live, which needs ruleset nextRules + 1 to be live and implemented by an
  image (`LiveAt.ruleset`). Validators holding more than 2/3 of the power must also run that
  ruleset's software. The model has no software versions, so this is part of what the online
  keys of `CommitteeLive` stand for.

## What H4 does not say

- **Normal-operation liveness.** H4's path always runs a governance recovery. It says nothing
  about landings continuing without governance, about how long a recovery takes (LIMIT-12-2
  lists the DAO's authorization delay, L1 finality, reconstruction, signer migration and first
  settlement), or about how many blocks it discards.
- **Adversarial scheduling.** The claim is existential: some sequence of calls exists, with
  every caller cooperating. It does not cover griefing, such as re-enqueueing blanked
  transactions (LIMIT-12-20) or registration races while a recovery is being authorized
  (RECOV-8.1-7).
- **The DAO's recovery policy (SPEC 8.1).** When to recover (RECOV-8.1-5: never for slow
  progress), settling to the last provable grid point first (RECOV-8.1-6), and the checks
  before authorizing (RECOV-8.1-7, for example that no party holds 1/3 or more). These are
  DAO duties the model does not encode. H4 shows the recovery mechanism works from every
  state that meets `LiveAt`; it does not say the DAO should use it in that state. The path
  recovers even from healthy states, discarding any unsettled blocks above c (RECOV-8-56).
- **Recoveries that need exclusions or blanking.** The path uses only plain recoveries. When
  the committee elected at R is not live without excluding members (LIMIT-12-2), `LiveAt`
  does not hold. When a queued transaction must be blanked, either the EL can neither execute
  it nor complete its single-transaction trial empty, which fails `LiveAt.ruleset`, or the
  guests cannot prove it, which fails `proofComplete`. Either way H4 says nothing.
- **Uninitialized deployments.** H4 assumes `initializeInbox` has succeeded. A
  misconfigured deployment whose initialization fails is a failed deploy.

## Joint witness

`RecoveryNonVacuity.all_premises_satisfiable` shows that one environment, registry and
engine meet H1–H3's fifteen `Premises` and H4's `RecoveryPremises` together, with a reachable
initialized world that meets `LiveAt`. `live_recovers` then applies H4's proof there: in that
environment the path does reach an accepted landing. The witness is restricted:

- a new network only: `initializeInbox` writes S = 0, and `setOrigin`, `correctStart`,
  `unzenProve` and the Unzen premises are not exercised;
- K = 1, so the landed segment is one block, `grid` holds trivially and no epoch switch falls
  inside the segment;
- one online key, which signs every vote;
- one catalogue definition, used for every ruleset number, and every image implements only
  ruleset 0;
- a classical verifier: a proof of image I for statement d is accepted exactly when I
  certifies d over the L1 prefix that d's reference hash commits to. This is an ideal sound
  and complete checker, not an oracle for a World. It ignores the verifier version, backend
  and proof bytes;
- an engine that attributes every precommit;
- a payload check that accepts any one to six blobs;
- an empty forced-inclusion queue.

Commitments are ideal unbounded Nat codes, not Keccak.

## Evidence

- **Claim.** `CURRENT-H4` in `spec-coverage.json` cites the clauses of the section 1
  liveness bullet and of LIMIT-12-2, under a new `recovery` boundary that lists the premises,
  hypotheses and limits above.
- **Narrow rule edges.** CONS-3.2-2 (block number and parent hash) and RECOV-8.4-13 (anchors no
  earlier than R) cite `Recovery.segment`; RECOV-8-58 (do not rewind the settled prefix) cites
  `Recovery.recoverable` and `Headlines.recoverability`. Each is an existence result about the
  path's own segment or landing, not a check on every block or recovery.
- **Trap theorem.** `Recovery.offgrid_no_landing` cites only the 8.3 checks clause, for
  RECOV-8.3-3a's grid check on plain recovery and landing. It no longer cites the
  verifier-failure clause: in the spec, the recovery RECOV-8-34 requires can be a structural
  one, so the theorem is not evidence for RECOV-8-34. Clause totals are unchanged, because
  other theorems also cite that clause.
- **Totals.** 61 partial / 507 deferred clauses (38 / 530 before H4), and 44 narrow partial /
  36 supporting / 528 deferred binding rules (41 / 36 / 531 before), plus 32 deferred
  assumption and limitation rows.

H4 adds no evidence for these:

- RECOV-8.4-11 (the FI cursor starts at the origin head): it is an input fact of the segment,
  not derived.
- PROOF-6.2-19 (a numeric epoch alone cannot authorize a committee): a soundness restriction
  that a construction does not exercise.
- The planned-stop refusal of 10.1: `recover` clears the stop, so the segment only ever sees
  `stopTime` = 0.
- Committee 0: the path always runs a recovery, so its committee is always a recovery
  committee.
- RECOV-8-39, RECOV-8-40a to 8-42 and RECOV-8-43 to 8-46 (list validation, exclusions and
  blanking): the path uses only empty lists.
- MODEL-1-1 and MODEL-1-2: assumed as `proofComplete`.

The review-surface lock grows from 1,433 to 1,464 constants: the H4 statement definitions,
the new headline and witness roots and their model closure. `Claims` and `recover` change.
