# Etna recoverability (H4)

Authorities: main `2e6763e21bc236cfcda6011d164b32040f9e0c8d` (2026-11-19) for SPEC,
ACCEPTANCE, ANCHORLESS and SWITCH, as for the rest of this package.

H1–H3 are safety claims: they say that nothing bad happens. Most Etna design bugs found so far
were of another kind: permanent halts, where no landing could ever succeed again. No safety
claim catches those. H4, `Recoverability`, is the fourth headline claim and is aimed at them:
from every reachable state, under named premises and hypotheses, there is a way back to an
accepted landing. It is proved in Lean with no new axioms.

This report says what H4 claims, how the proof reaches a landing, what each premise and
hypothesis assumes and who must make it true, three changes to the machine, and what H4 does
not say.

Terms used below:

- **Landing** (`land`): the L1 call that settles a batch of L2 blocks with two accepted proofs
  and moves the **checkpoint** c, the height of the last settled L2 block.
- **Start** S: the L2 height Etna starts from. On a new network S = 0. On a **switching
  network**, which takes over from the existing (Unzen) rollup, S is the last Unzen block,
  written by `setOrigin`.
- **Governance recovery** (`recover`, SPEC 8): a DAO call that starts a new **generation**
  from the current checkpoint c, reselects the committee at the L1 block R where it executes,
  and discards unsettled blocks above c. Its **exclusions** set listed members' exits to R, so
  they are out of R's election (RECOV-8-41). A **plain recovery** blanks no forced-inclusion
  entry and makes no structural upgrade; it may exclude members. A **structural upgrade** is a
  recovery that also installs new parameters (SPEC 10.1).
- **Verifier-failure rollback** (`rollback`, RECOV-8-24 to 8-34): a DAO Inbox upgrade that
  restores the checkpoint written by the last trusted landing after a bad proof was accepted.

## Where it lives

| What                       | Lean                                                                                                                                                                                                                                                                            |
| -------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Claim                      | `Recoverability`, `RecoverableAt`, `RecoveryPremises`, `LiveAt` in `EtnaStatements/Current.lean`                                                                                                                                                                                |
| Vocabulary                 | `CallTrace`, `RecoveryCall`, `RecoveryTrace`, `ExecutionLive`, `RulesetLive`, `CommitteeLive`, `WindowBound` in `EtnaModel/CurrentRecovery.lean`; `LiveRules` in `EtnaStatements/Current.lean`                                                                                  |
| Proof                      | `Recovery.prepare` (L1 calls), `Recovery.segment` (L2 blocks), `Recovery.recoverable` (certificate and landing) in `EtnaProofs/CurrentRecovery*.lean`                                                                                                                           |
| Headlines                  | `Headlines.recoverability`, `Headlines.deployed_recoverability` and the four-part `Headlines.claims` in `EtnaProofs/Headline/Current.lean`                                                                                                                                      |
| Joint witness              | `RecoveryNonVacuity.all_premises_satisfiable` and `live_recovers` in `EtnaWitnesses/NonVacuity/CurrentRecovery.lean`; for a switching network, `RecoverySwitchNonVacuity.all_premises_satisfiable` and `live_recovers` in `EtnaWitnesses/NonVacuity/CurrentRecoverySwitch.lean` |
| Statement and audit checks | `tests/CurrentRecovery.lean`, `CurrentRecoveryProof.lean`, `CurrentRecoveryWitness.lean`, `tests/test_current_recovery.py`                                                                                                                                                      |

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

`RecoveryTrace` fixes which calls that sequence may use. Each step is one modelled call, and
`RecoveryCall` judges it:

```lean
def RecoveryCall : Call → Prop
  | .rollback .. => False
  | .recover request => request.clear = [] ∧ request.upgrade = none
  | _ => True
```

Every call is allowed except `rollback`. A `recover` must be plain: an empty forced-inclusion
blanking list and no upgrade; its exclusion list is free. The claim itself therefore keeps to
the DAO's call-level limits: no rollback, no blanking of provable forced-inclusion entries
(RECOV-8-45), and no structural upgrade. The path's one recovery excludes exactly the members
that `LiveAt.window` names.

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
upgrades, under the same per-upgrade authorization that `deployed_claims` uses for H1–H3. In
that authorization a rollback must restore the last trusted landing after a verifier failure
(`Governance.RollbackAuthorized`, RECOV-8-28); under H1's premises no rollback qualifies, so
such a history has none (`Headlines.deployed_rollback_free`).

What the proof builds and what it takes from premises:

- **Built:** every L1 call; one L2 block at c + 1, valid under the model's block-validity rules
  (`Blocks.Valid`), with its committee votes; the batch certificate; and the landing checks.
- **Supplied by hypotheses, existentially:** each block's execution header and hashes (the
  `ruleset` hypothesis), the online validators' signatures (`window`) and the blob list
  (`payloadLive`). The proof chooses inputs; these say that execution, signing and data
  availability then produce a result. No EL, signer or DA implementation is modelled. The
  `ruleset` hypothesis asks the EL to accept only blocks shaped like the ones the proof builds:
  a timestamp above the parent's, the block's own witness bytes, the parent's hash, a fee share
  of 100 and the anchor's state root as the parent beacon root.
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
   - If the written start differs from that header in height, hash or state root and nothing
     has landed, the owner calls `correctStart` with it.
   - If the Unzen lane has not finalized its last proposal, anyone calls `unzenProve` with the
     proof that the `unzen` hypothesis supplies, so the first-landing check (LAND-6.1-8a)
     passes. That check also compares the height of the Unzen checkpoint with S; it holds
     because the checkpoint and the start both come from the lane's final header.

   Once something has landed, H1's first-landing fence already shows that the start is the
   Unzen lane's final header.

3. **Image and verifier.** The owner registers an image that implements every ruleset the
   schedule will select (`image`) and selects the verifier version that `proofComplete` names
   (`verifier`).
4. **Recovery.** The owner calls `recover` at R with the current generation, checkpoint c and
   nonce, `validUntil` set to R's time, the exclusions that `window` names and an empty
   blanking list. The registry sets each excluded bond's exit to R and changes nothing else
   (`Recovery.recover_excludes`), so those members are out of R's election
   (`Recovery.excluded_ineligible`) and the committee that `window` assumes live is the one
   elected.

   - When `LiveRules`' first case holds (the current rulesets live), the recovery keeps the
     rule schedule (`rules` = 0).
   - Otherwise ruleset nextRules + 1 is live, and the recovery installs it (`rules` =
     nextRules + 1, LIMIT-12-21).
   - Either way the recovery is plain: it keeps the parameters, and the rest of the path reads
     the committee configuration and the parameters from the recovered state. SPEC 8.3 no
     longer checks c against a grid (RECOV-8.3-3a is retired), so `recover` accepts at every c.

5. **Close R.** Advance L1 to R + 2, so the model's L1 snapshots at R and R + 1 are closed.
6. **Block.** Build one block at height c + 1 on c's header, which H1 shows is retained and
   hash-bound (on a switching network at c = S, the Unzen final header with Etna's zeroed
   fields).
   - The block anchors at R. Its timestamp is max(c's timestamp + 1, R's time).
   - Its committee is the recovery committee elected at R, because its anchor and the
     generation's origin block are R. It commits in round 0 with votes from online keys
     holding more than 2/3 of the power.
   - Forced inclusion: the queue head is included as the first transaction when it is
     canonical and executes at position zero. When it is due and is not canonical, or its
     single-transaction trial completes empty, it is skipped. Otherwise the block waits.
   - The block's execution header comes from the `ruleset` hypothesis.
7. **Landing.** The segment's statement is certified at L1 reference R + 1, with the archive
   rooted at c's header and no earlier headers. `proofComplete` gives two accepted proofs and
   `payloadLive` a blob list, so `land` accepts the landing from c to c + 1. A landing may end
   at any height above c, and with h = c + 1 and proof origin p = c there are no heights
   strictly inside (p,h), so the landing carries no leaves and its inner cut list is empty
   (`land_single_block`), which L1 hashes as keccak256("").

The path never calls `rollback`, `scheduleRules` or `scheduleStop`, and makes no structural
upgrade. It needs no rollback because `VerifierSound`, one of
H1's premises, makes every landed checkpoint genuine, so a recovery from the current c
suffices. This is also why `RecoveryPremises` extends
`FundPremises`: the path uses H1's conclusion that c's header is retained and hash-bound.

## Premises

`RecoveryPremises` is H1's five fields (`FundPremises`, see the README) plus five more:

| Field                   | What it assumes                                                                                                                                                                                                                                                                                                                                                                                                                                 | Spec                                                                                  | Who must make it true                                                                                                                         |
| ----------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| `recoveryClock`         | L1 time strictly increases with block number. The same fact as `currentClock`                                                                                                                                                                                                                                                                                                                                                                   | Ethereum L1 behaviour                                                                 | Ethereum L1                                                                                                                                   |
| `recoveryCatalogueHash` | Catalogued EL transaction bytes hash to the environment's transaction hash. The same fact as `currentCatalogueHash`                                                                                                                                                                                                                                                                                                                             | FI-7.1-2                                                                              | Hash function; EL catalogue                                                                                                                   |
| `proofComplete`         | One verifier version accepts, for every statement an image certifies, two proofs of that image, at least one of them ZK                                                                                                                                                                                                                                                                                                                         | MODEL-1-1, MODEL-1-2                                                                  | Etna zkVM/TEE guests and provers, within their resource limits; the DAO's verifier choice                                                     |
| `payloadLive`           | At most one block of at most 124,000 bytes fits in one to six blobs that the payload check accepts                                                                                                                                                                                                                                                                                                                                              | 3.4 size bound, 5.2, 6.3                                                              | Blob encoding and Ethereum data availability                                                                                                  |
| `unzenStart`            | On a switching network, every header that a valid proof of the Unzen Inbox's final proposal authenticates is a usable Etna start: nonzero height, hash and state root; room for one more height below 2^48; a state root that passes the start-implementation check; and a hash-bound start header with Etna's zeroed fields. `unzenProve` is permissionless, so any valid final proof may land first; this is why the premise covers every one | LIMIT-12-9, START-10-5, START-10-5a, LAND-6.1-8a, PROOF-6.2-46a, PARAM-11-12a, SWITCH | The switching deployment, which puts the Etna L2 `SignalService` implementation in place on L2 before S (SWITCH.md); the existing Unzen guest |

The first two repeat fields of `Premises`, so that each headline names exactly what it rests
on. The audit requires H4's proof to read every field of `RecoveryPremises`.

## Per-state hypotheses

`LiveAt` holds seven conditions on the starting state w, not on the environment. The audit
requires H4's proof to read each of them.

| Field        | What it assumes about w                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   | Spec                                                                                          | Who must make it true                                                                                                                          |
| ------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| `generation` | generation + 2 < 2^48 (the path may run both `correctStart` and `recover`)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                | RECOV-8-47                                                                                    | Counter headroom; no realistic deployment exhausts it                                                                                          |
| `nonce`      | recoveryNonce + 1 < 2^256                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 | RECOV-8.3-11                                                                                  | Counter headroom                                                                                                                               |
| `rules`      | nextRules + 1 < 2^48                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      | RECOV-8-47a, appendix A's `recover(…, uint48 rules)`, STOR-B-15a                              | Counter headroom                                                                                                                               |
| `height`     | c + 1 < 2^48                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              | 6.1 land (48-bit heights)                                                                     | Height headroom                                                                                                                                |
| `window`     | Some later L1 block R, with room in 48 bits, whose time is more than one second past each of: the current L1 time plus the largest `maxAnchorAge` of any generation so far, `forkTime`, and the genesis timestamp. At R, once the recovery excludes a list of members (sorted by bond id, each an issued bond named by its entry key; possibly empty), the election over the registry succeeds, and a set of online keys that can sign every vote holds more than 2/3 of the elected power (`CommitteeLive` on `excluded w R exclusions`)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 | 3.4 rule 7 (anchor age), START-10-5a, 4.3, RECOV-8-17 to 8-21, RECOV-8-38 to 8-41, LIMIT-12-6 | Ethereum L1; the deployer, by picking a genesis timestamp and `forkTime` that L1 reaches; validators online and signing; enough eligible stake |
| `ruleset`    | `LiveRules`: either the active and next rulesets are live and one image implements both; or ruleset nextRules + 1 is live and some image implements it. A ruleset is live (`ExecutionLive`) when, for every parent header and every FI cursor, timestamp above the parent's, anchor and witness bytes a block producer picks, its EL accepts some hash-bound child with an empty transaction list; and when the witness bytes are a canonical forced transaction of at most 8,192 bytes, that transaction either executes as the only transaction or its single-transaction trial completes empty. The witness bytes are the queue head's raw bytes in a block that carries a forced-inclusion witness, and empty otherwise. The EL accepts a child when its execution and payload checks pass, at those witness bytes, for every block body that names the parent's hash, pays a fee share of 100 and carries the anchor's state root as its parent beacon root (the body fields the EL reads, 3.2); the other body fields are left free | MODEL-1-1 (EL side), 7.2 trial, START-10.1, START-10.1-14e, LIMIT-12-21, 6.1, RECOV-8.3-3a    | The ruleset's EL and guest images; the DAO and validators for rule upgrades; off the grid, the DAO's K change in a new ruleset                 |
| `unzen`      | On a switching network, the Unzen lane has finalized its last proposal, or a valid proof of that proposal, linked to the lane's last finalized hash, exists from the current lane state                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   | LIMIT-12-9, LAND-6.1-8a                                                                       | Unzen provers and the existing Unzen guest                                                                                                     |

Why `window` has those three bounds: the batch parent's timestamp is bounded by its anchor's
L1 time plus that generation's `maxAnchorAge` (for c above S), by `forkTime` (a switching
start) or by the genesis timestamp (a new network at S = 0). R must be late enough that the
new block, anchored at R, keeps its timestamp after the parent's and within the anchor-age
limit. `WindowBound` takes all three bounds on every network, whichever case applies.

## No landing grid

Before #22412, landings ended only at grid points: heights h with h − S a multiple of K. A
rollback across a K change could restore a checkpoint off the new grid, from which only a
structural recovery installing a suitable K led to a landing. H4's path then carried a
structural branch that installed K = 1 in a new ruleset, `LiveAt.ruleset` had a grid condition
(`OnGrid`), and this report described that rollback grid trap with its witnesses. #22412
removed the grid (PARAM-11-9 and RECOV-8.3-3a are retired): a landing may end at any height
above c. So no reachable c is stuck, the path always runs one plain recovery and lands c + 1,
and the trap theorem, its witnesses, `OnGrid` and the structural branch are deleted. The
[PR #22412 alignment](alignment-22412.md) lists the changes.

## Model changes

Three changes: two to `recover`'s upgrade branch and one to `land`'s first-landing fence.
`recover` and `land` are part of H1–H3's statements, so each change alters the machine they
describe; the review-surface lock records all three.

**The genesis cutoff, which the proof forced.** The proof needs every certificate's readiness
check to pass, and that check needs `genesisCutoff` to be at most the generation's origin L1
block. The model's `recover` used to let a structural upgrade install any `genesisCutoff`. A
reachable upgrade could then set a cutoff above every later L1 block, and no landing would be
accepted again.

The spec does not allow this. `genesisCutoff` is set once at Inbox initialization
(PARAM-11-4, START-10-2) and stored in slot 279 (STOR-B-5). START-10.1-2a puts generation 0's
genesis in the deployment core, which only a migration to a new Inbox may change.

`recover`'s upgrade branch now also requires the new parameters to keep the stored cutoff
(`parameters.genesisCutoff = w.inbox.genesisCutoff`), so a structural upgrade can change the
other parameters but never the genesis cutoff. This narrows the machine. The removed
behaviour is one the spec forbids.

**No planned-stop check, as in SPEC 8.3.** The upgrade branch used to require a planned stop in
effect at c, with c at or above S and c − S a multiple of the stop's grid. That wrote the main
procedure of START-10.1-14e (schedule a stop, let production end, settle that height, then
recover from it) as checks. SPEC 8.3 has no such check, so the model refused structural
recoveries the spec accepts, such as vector 14e.k's recovery from a settled c below a height
that cannot settle. The branch now checks only that the new parameters are valid, that `rules`
is nonzero (vector 14e.g) and that the genesis cutoff is kept. Since #22412 retired
RECOV-8.3-3a, `recover` has no grid check at all. This widens the machine by behaviour the spec
allows. No H1–H3 proof changed; one H4 proof step that read the guard by position did.

**The first landing checks the Unzen checkpoint's height.** LAND-6.1-8a reads the Unzen
checkpoint at S and requires its hash and state root to equal the start's (SWITCH.md
section 5, condition 3). The model's Unzen record kept only the last proof's hash and state
root, so a start S = 5 written with the hash and state root of the Unzen block at height 10
passed `land`'s first-landing fence. The contract would revert, since no checkpoint at height 5 has
that hash. `unzenProve` now records the proven header's height, and the fence requires it to
equal S. This narrows the machine by behaviour the contract refuses. H1 did not need the
check, since equal hashes of hash-bound headers mean equal heights, but `Custody.FirstFence`
restates the fence and gained the same conjunct. `tests/CurrentGuards.lean` checks that the
shifted start is refused.

## Deployment-shaped conditions and known limitations

Some hypotheses are not protocol properties but duties of a deployment or of other parties.
They get no Lean counterexample. For each, here is who must make it true.

- **Genesis timestamp and `forkTime`.** On every network, `window` needs an L1 block, within
  48-bit block numbers, more than one second past both the genesis header's timestamp and
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
  deployment must put the Etna L2 `SignalService` implementation in place on L2 before S,
  which the guest checks at S (PROOF-6.2-46a, PARAM-11-12a, SWITCH.md), and the existing Unzen
  guest must authenticate real headers with nonzero fields.
- **LIMIT-12-6, empty committee.** Recovery cannot create a quorum from nothing.
  `CommitteeLive` assumes that the election at R, after the recovery's exclusions, succeeds
  and that online keys hold more than 2/3 of its power. Excluding offline members is the
  usual way to get there (LIMIT-12-2); eligible stake must still exist, and the validators
  left must be online.
- **LIMIT-12-9, start written by a multisig.** A wrong start stops Etna until the DAO
  rewrites it. The path does this with `correctStart` while nothing has landed; the
  final-proof part is the `unzen` hypothesis above.
- **LIMIT-12-21, upgrades depend on the DAO and validators.** A defective ruleset that has
  taken effect is replaced by recovery's `rules`. The path does this when the current
  rulesets are not live, which needs ruleset nextRules + 1 to be live and implemented by an
  image (`LiveAt.ruleset`). Validators holding more than 2/3 of the power
  must also run that ruleset's software. The model has no software versions, so this is part
  of what the online keys of `CommitteeLive` stand for.

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
  progress), settling to the last provable block first (RECOV-8.1-6), and the checks
  before authorizing (RECOV-8.1-7, for example that no party holds 1/3 or more). These are
  DAO duties the model does not encode. H4 shows the recovery mechanism works from every
  state that meets `LiveAt`; it does not say the DAO should use it in that state. The path
  recovers even from healthy states, discarding any unsettled blocks above c (RECOV-8-56).
- **Recovery after a verifier failure.** H4 assumes `VerifierSound`. After a real verifier
  failure it is false, so H4 does not cover the rollback and the recovery that follow, even
  once the DAO replaces the verifier.
- **Recoveries that need blanking.** The path blanks nothing. When a queued transaction must
  be blanked, either the EL can neither execute it nor complete its single-transaction trial
  empty, which fails `LiveAt.ruleset`, or the guests cannot prove it, which fails
  `proofComplete`. Either way H4 says nothing. Exclusions are covered: `LiveAt.window` names
  the members to exclude. No joint witness uses a nonempty exclusion list, so that case is
  proved but not shown satisfiable.
- **Structural upgrades.** The path's recovery is plain: it never installs new parameters. H4
  says nothing about a recovery that must change them (START-10.1-14e).
- **Uninitialized deployments.** H4 assumes `initializeInbox` has succeeded. A
  misconfigured deployment whose initialization fails is a failed deploy.

## Joint witness

`RecoveryNonVacuity.all_premises_satisfiable` shows that one environment, registry and
engine meet H1–H3's fifteen `Premises` and H4's `RecoveryPremises` together, with a reachable
initialized world that meets `LiveAt`. `live_recovers` then applies H4's proof there: in that
environment the path does reach an accepted landing. The witness is restricted:

- a new network only: `initializeInbox` writes S = 0, and `setOrigin`, `correctStart`,
  `unzenProve` and the Unzen premises are not exercised;
- the landed segment is one block, as on every H4 path, so no epoch switch falls inside it;
- `LiveAt.ruleset` holds by `LiveRules`' first case, so the path keeps the rulesets and its
  rules replacement is not exercised;
- one online key, which signs every vote;
- one catalogue definition, used for every ruleset number, and every image implements only
  ruleset 0;
- the ruleset's execution check reads only the header's two hashes, and its payload check
  accepts every transaction list and witness bytes;
- a classical verifier: a proof of image I for statement d is accepted exactly when I
  certifies d over the L1 prefix that d's reference hash commits to. This is an ideal sound
  and complete checker, not an oracle for a World. It ignores the verifier version, backend
  and proof bytes;
- an engine that attributes every precommit;
- a payload check that accepts any one to six blobs;
- an empty forced-inclusion queue;
- nothing has landed in the reachable world `live`, so the second part of the conclusion (the
  new checkpoint is above the starting one when something had landed) is not exercised.

`RecoverySwitchNonVacuity.all_premises_satisfiable` (in
`EtnaWitnesses/NonVacuity/CurrentRecoverySwitch.lean`) does the same for a switching network.
Mainnet is one: it takes over from the Unzen rollup. The environment is the one above with the
switching fields set: an Unzen Inbox, a fork time that L1 reaches at block 3, and one legacy
header L at height 5. L is hash-bound, its timestamp is before the fork time, and a valid proof
of the Unzen Inbox's final proposal authenticates it. In the reachable world `live`, the origin
writer has set S = 5 from L and no Unzen proof has been accepted, so `LiveAt.unzen` holds
because a valid proof of the final proposal exists. `live_recovers` applies H4's proof there.
Nothing has landed and the Unzen lane has no checkpoint, so the landing the path reaches is the
first one, at c = S. To get there the path proves the lane with `unzenProve`, and the landing
passes the first-landing fence, including its check that the Unzen checkpoint is at S.
`tests/CurrentRecoveryWitness.lean` pins that the fence refuses at `live`, passes after that
proof, and refuses a start at height 6 that has L's hash and state root. This witness keeps the
first one's restrictions, except those of a new network, and adds these:

- one legacy header, and the Unzen guest accepts one proof, of the final proposal 1;
- `unzenParent` returns 0, the empty lane's finalized hash, so that `unzenProve`'s link check
  passes. `UnzenExtension` therefore holds vacuously: its only valid proof has boundary 0, and
  no hash-bound header has EL hash 0. `NonVacuity.CurrentSwitch` has the same limit;
- the written start equals the Unzen final header, so the path's `correctStart` branch is not
  exercised;
- `LiveAt.ruleset` holds by `LiveRules`' first case;
- no Unzen implementation runs: the legacy proof is one fixed value.

`tests/CurrentRecoveryProof.lean` applies `Recovery.recoverable` under `LiveRules`' second
case, where the recovery installs ruleset nextRules + 1.

Commitments are ideal unbounded Nat codes, not Keccak.

## Evidence

- **Claim.** `CURRENT-H4` in `spec-coverage.json` cites the clauses of the section 1
  liveness bullet and of LIMIT-12-2, under a new `recovery` boundary that lists the premises,
  hypotheses and limits above.
- **Supporting rule edges.** CONS-3.2-2 (block number and parent hash) and RECOV-8.4-13
  (anchors no earlier than R) cite `Recovery.segment`. Each is an existence result about the
  path's own block, not a check on every block. Since #22412 the segment is one block, so the
  conclusion includes `bs.length = 1`, which names none of the theorem's arguments; the audit's
  Rule P then classes `segment` as supporting, not property, and both rules, which were narrow
  partial, are supporting. `segment` was also the only property citing sixteen clauses of SPEC
  3.2, 3.3, 3.4, 4.3, 6.2, 6.4 and 8.4, which are now deferred.
- **RECOV-8.3-3a is retired** by #22412, with the grid it checked.
- **Totals.** 60 partial / 508 deferred clauses (38 / 530 before H4), and 43 narrow partial /
  37 supporting / 528 deferred binding rules (41 / 36 / 531 before H4), plus 32 deferred
  assumption and limitation rows. H4 itself added 2 narrow partial rules; the extra supporting
  rule is RECOV-8-28, from H1's rollback-target duty (`Governance.rollback_target_unique`).
  At the #22412 pin the package has 52 partial / 526 deferred clauses and 43 narrow partial /
  44 supporting / 517 deferred binding rules, plus the same 32 rows.

H4 adds no evidence for these:

- RECOV-8.4-11 (the FI cursor starts at the origin head): it is an input fact of the segment,
  not derived.
- PROOF-6.2-19 (a numeric epoch alone cannot authorize a committee): a soundness restriction
  that a construction does not exercise.
- The planned-stop refusal of 10.1: `recover` clears the stop, so the segment only ever sees
  `stopTime` = 0.
- Committee 0: the path always runs a recovery, so its committee is always a recovery
  committee.
- RECOV-8-39, RECOV-8-42 and RECOV-8-43 to 8-46 (list validation, forfeiture and blanking): the
  path blanks nothing. Its exclusions are evidence for RECOV-8-38, 8-40a and 8-41, through
  `Recovery.recover_excludes` and `Recovery.excluded_ineligible`.
- MODEL-1-1 and MODEL-1-2: assumed as `proofComplete`.
- RECOV-8-58 (do not rewind the settled prefix): H4's statement does not show it. The
  supporting theorems `Governance.recover_origin_exact` and `Governance.recovery_preserves_head`
  show that a recovery keeps the checkpoint; they are cited for RECOV-8-48.
- RECOV-8.1-3 to 8.1-5 (recovery timing and the DAO's policy): H4 says nothing about how soon
  a recovery runs, and SPEC 8.1 policy is outside the claim (see What H4 does not say).

The review-surface lock grew from 1,433 to 1,464 constants when H4 was added: the H4 statement
definitions, the new headline and witness roots and their model closure. `Claims` and `recover`
changed. Letting H4 leave an off-grid state added `OnGrid` and changed `CallTrace`,
`RecoveryCall`, `NoRollbackOrUpgrade`, `LiveRules` and `LiveAt`. The switching joint witness
added only its own root, since its statement names no new definition. Making the
deployed-history headlines (`Headlines.deployed_claims`, `deployed_rollback_free` and
`deployed_recoverability`) roots added the raw DAO upgrade machine and its authorization
duties, for 1,617 constants then. Letting the recovery exclude members (RECOV-8-41) added
`excluded` and changed `RecoveryCall` and `LiveAt`, for 1,746 constants. H1's bridge read-path
conjunct (RECOV-8-27a) made it 1,790. #22412 removed the grid, `OnGrid`,
`NoRollbackOrUpgrade`, the trap witnesses and the validator-state certificate roots, and
simplified `RecoveryCall` and `WindowBound`, for 1,730 constants at this revision.
