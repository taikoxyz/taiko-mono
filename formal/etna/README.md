# Etna design verification

The authorities are `SPEC.md`, `ACCEPTANCE.md`, `ANCHORLESS.md` and `SWITCH.md` under
`packages/protocol/docs/etna`, pinned to main `d18357214fab30ea512ae9858a11699806d72ba1`
(2026-11-13, after #22348). This package contains only the current design; the archived 2026-10-30 model,
its vectors and reports were removed and remain readable at formal revision
[`583bc2620`](https://github.com/taikoxyz/taiko-mono/tree/583bc2620258838e75ce353c11f9344616ac1020/formal/etna).

Spec pull requests do not run the formal jobs, so a spec change never fails on these pins.
When the spec moves, the next pull request that touches `formal/etna` fails on the pins until
the model is re-aligned and re-pinned, and the nightly `etna-formal-full` job reports the
drift.

## What is proved, and what is not

This package proves **conditional, design-level safety and recoverability** of the decoded
Etna machine. Exact claims live in `EtnaStatements/Current.lean` (277 lines); composition is in
`EtnaProofs/Headline/Current.lean`. Every claim holds for every reachable `Trace` from a
fresh deployment under explicit premises: **H1 assumes the five fields of `FundPremises`;
H2 and H3 assume all fifteen fields of `Premises`**, which extends `FundPremises`; **H4
assumes `RecoveryPremises`**, which extends `FundPremises` with five more fields, and the
seven per-state hypotheses of `LiveAt` (below).

- **H1, fund safety.** Every accepted landing extends one hash-bound checkpoint chain from an
  authenticated root; Etna and legacy (Unzen) signals stay disjoint; the start is written once.
  None of H1's five premises concerns consensus (signature soundness, codec, vote attribution
  or honesty), so H1 holds whatever the committee signs. This is the formal form of SPEC
  section 1's statement that even a committee acting maliciously as a whole cannot take funds
  on L1. H1 also states SPEC section 1's finality of checkpoints: every later run without a
  `rollback` keeps each retained signal and, once something has landed, each retained landing
  record and a checkpoint at least as high; and no rollback is authorized, because a rollback
  needs a bad landing (a verifier failure) and under H1's premises there is none.
- **H2, accountable finality.** Two conflicting commits at the same height and round imply an
  overlap of more than one third of the voting power with authentic evidence and an executable
  funded slash; with honest locking and a Byzantine minority, valid chains agree.
- **H3, forced-inclusion integrity.** No valid landing skips a due forced inclusion: FIFO
  service, due-only skips, no early skip, and only `land` advances the head. This is a safety
  property of landings. It does **not** promise that a due inclusion is ever landed.
- **H4, recoverability.** From every reachable, initialized state that meets `LiveAt`, some
  sequence of modelled calls with no `rollback`, no exclusions, no forced-inclusion blanking and
  no structural change other than K reaches an accepted `land`; if anything had landed before,
  that landing ends above the starting checkpoint. `LiveAt` has no grid condition: when the
  checkpoint is off the current grid, the path's recovery installs K = 1 in a new ruleset, so
  it needs ruleset nextRules + 1 to be live. Under H4's premises only a rollback can leave the
  checkpoint off the grid, and H1 shows that no rollback is authorized. So this case arises
  only in a raw `Trace` with an unauthorized rollback; authorized histories never reach it.
  After a real verifier failure, H4's premises fail and it says nothing. L2 block production
  is constructed, not assumed: the proof builds the K valid blocks and their certificate from
  hypotheses about execution, signing and data availability. Proof completeness
  (MODEL-1-1/1-2) is a premise, so it is assumed, not shown. The
  [recoverability report](reports/recoverability.md) explains the path, each premise and
  hypothesis, and a trap that only a structural recovery leaves, which an authorized history
  reaches only after a verifier failure.

Not covered here: normal-operation liveness (landings continue without governance);
adversarial scheduling, since H4's path is one that exists when every caller cooperates; the
DAO's recovery policy in SPEC 8.1 (when to recover, and the checks before it), since H4 shows
that the recovery mechanism works from every such state, not that the DAO should use it there;
recoveries with exclusions or blanking, and structural upgrades other than a K change; a
checkpoint off the grid when ruleset nextRules + 1 is not live, since a K change rides in a new
ruleset; recovery after a verifier failure, even once the verifier is replaced, since H4's
premises assume a sound verifier; refinement to the Solidity contracts, the Rust client or the
zkVM guests; CometBFT's implementation, cryptography, data availability, and economic
security. Cross-round equivocation (amnesia) is outside H2, as the spec states.

## Premises and who must discharge them

H1–H4 are only as strong as these premises and hypotheses. Of the fifteen rows in the first
table, six describe the environment or deployment; the others are obligations on code or
cryptography that this package does not verify.

The first five rows form `FundPremises`, the record H1 is stated over. The audit requires
H1's own proof to read each of them, so a premise H1 stops needing must leave the record.
`Premises` extends `FundPremises` with the other ten rows, which H2 and H3 use.

| Premise field               | What it assumes                                                                                                                                  | Who must make it true                                                          |
| --------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------ |
| `currentPrimitives`         | Genesis header is hash-bound; equal EL hashes mean equal EL fields; a valid Unzen proof authenticates its decoded EL header before the fork time | Hash collision resistance; existing Unzen guest and verifier                   |
| `currentVerifierSound`      | Every accepted landing proof with a sound backend certifies its statement, including both validator-state hashes, for the selected rulesets      | Etna zkVM/TEE guests, proof systems, `ZkRequiredVerifier`, DAO verifier choice |
| `currentReferenceBinding`   | Equal L1 block hashes imply equal L1 prefixes                                                                                                    | Hash collision resistance (modeled as an injective map)                        |
| `currentRegistryGenesis`    | The registry starts fresh, with no prior identities or history                                                                                   | Deployment procedure                                                           |
| `currentUnzenExtension`     | A valid Unzen proof extends its decoded parent to a higher height                                                                                | Existing Unzen guest                                                           |
| `currentStandardToken`      | The bond token behaves as a standard ERC-20 transfer                                                                                             | Token deployment                                                               |
| `currentSignatureAgreement` | Signed consensus bytes refine to the registry's signature check                                                                                  | Comet sign-bytes in the Rust client and the Solidity verifier                  |
| `currentBountyBound`        | `slashBountyBps < 10000`                                                                                                                         | Registry initializer (checked on chain)                                        |
| `currentCodec`              | Comet header/envelope codec is canonical, and a valid block's Comet hash and parent fix its whole header, including the validator-state hash     | Rust client and stock CometBFT parity; CometBFT's deterministic state update   |
| `currentVoteAttribution`    | Every commit vote is attributed to a real precommit of the fixed engine                                                                          | CometBFT engine and validator operation                                        |
| `currentClock`              | L1 time strictly increases with block number                                                                                                     | Ethereum L1                                                                    |
| `currentCatalogueHash`      | Catalogued EL transaction bytes hash to the environment's transaction hash                                                                       | Hash function; EL catalogue                                                    |
| `currentSignatureSound`     | An accepted signature authenticates the key holder                                                                                               | secp256k1 verification in Solidity                                             |
| `currentSelfAllowance`      | The registry has no allowance to itself at genesis                                                                                               | Token deployment                                                               |
| `currentEvidenceWindow`     | `0 < evidenceWindow ≤ withdrawalDelay`                                                                                                           | Deployment parameters                                                          |

H2's chain-agreement clause additionally assumes `ProtocolFinality.HonestExecutions`.
This separate antecedent supplies honest local locking rules and a Byzantine minority at
the checked heights.

H4's record, `RecoveryPremises`, extends `FundPremises` with the five fields below. The first
two repeat `currentClock` and `currentCatalogueHash`, so that each headline names exactly
what it rests on. The audit requires H4's proof to read every field of `RecoveryPremises`.
H4 depends on neither `Premises` nor any honesty or vote-attribution definition.

| Premise field           | What it assumes                                                                                                                                                                                                                                                                                                    | Who must make it true                                                                                      |
| ----------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------- |
| `recoveryClock`         | L1 time strictly increases with block number                                                                                                                                                                                                                                                                       | Ethereum L1                                                                                                |
| `recoveryCatalogueHash` | Catalogued EL transaction bytes hash to the environment's transaction hash                                                                                                                                                                                                                                         | Hash function; EL catalogue                                                                                |
| `proofComplete`         | One verifier version accepts, for every statement an image certifies, two proofs of that image, at least one of them ZK (MODEL-1-1/1-2)                                                                                                                                                                            | Etna zkVM/TEE guests and provers within their resource limits; the DAO's verifier choice                   |
| `payloadLive`           | Up to six blocks of at most 124,000 bytes each fit in one to six blobs that the payload check accepts                                                                                                                                                                                                              | Blob encoding and Ethereum data availability                                                               |
| `unzenStart`            | On a switching network, every header that a valid proof of the Unzen Inbox's final proposal authenticates is a usable Etna start: nonzero height, hash and state root, room for six more heights, a state root that passes the start-implementation check, and a hash-bound start header with Etna's zeroed fields | The switching deployment (the Etna `Anchor` in place at S, PROOF-6.2-46a, SWITCH.md); existing Unzen guest |

H4 also takes `LiveAt`, seven conditions on the starting state rather than on the
environment. The audit requires H4's proof to read each of them too. K is the current grid
(the landing interval), c the checkpoint height and S the start height.

| `LiveAt` field | What it assumes about the starting state                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        | Who must make it true                                                                                                             |
| -------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| `generation`   | generation + 2 < 2^48                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           | Counter headroom; no realistic deployment exhausts it                                                                             |
| `nonce`        | recoveryNonce + 1 < 2^256                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       | Counter headroom; no realistic deployment exhausts it                                                                             |
| `rules`        | nextRules + 1 < 2^48                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            | Counter headroom; no realistic deployment exhausts it                                                                             |
| `height`       | c + K < 2^48                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    | Height headroom; no realistic deployment exhausts it                                                                              |
| `window`       | A later L1 block R, with room in 48 bits, whose time is more than K seconds past each of: the current L1 time plus the largest `maxAnchorAge`, `forkTime`, and the genesis timestamp; at R the election succeeds and online keys that sign every vote hold more than 2/3 of the elected power (`CommitteeLive`)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 | Ethereum L1; the deployer (a genesis timestamp and `forkTime` that L1 reaches); online validators; eligible stake (LIMIT-12-6)    |
| `ruleset`      | Either c is on the grid once a start is written (c − S a multiple of K) and the active and next rulesets are live and share an image, or ruleset nextRules + 1 is live and has an image, with no grid condition. A plain recovery keeps K, so it needs c on the grid (RECOV-8.3-3a); off the grid the path's recovery installs K = 1, and a K change must be part of the definition the new `rules` names (START-10.1-3b, START-10.1-14e). So the second case plays two roles: on the grid, a rules replacement that keeps K; off the grid, the K = 1 structural ruleset. Rulesets carry no K in the model, so off the grid it reads: ruleset nextRules + 1 is published as the current rules with K = 1, and an image implements it; the model does not check that the definition includes K. A live ruleset's EL builds a valid empty child of every parent for every FI cursor, later timestamp, anchor and witness bytes (a forced transaction's raw bytes, or none) a block producer picks, and each canonical forced transaction of at most 8,192 bytes either executes at position zero or its single-transaction trial completes empty. Valid means the execution and payload checks accept, at those witness bytes, every block body that names the parent's hash, pays a fee share of 100 and carries the anchor's state root as its parent beacon root, the body fields the EL reads | Ruleset EL and guest images; the DAO and validators for rule upgrades (LIMIT-12-21); off the grid, a new ruleset for the K change |
| `unzen`        | On a switching network, the Unzen lane has finalized its last proposal, or a valid proof of that proposal exists from the current lane state                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    | Unzen provers and the existing Unzen guest (LIMIT-12-9)                                                                           |

Hash premises are a standard idealization: the models treat commitments as injective. Read a
claim that relies on them as "the claim holds, or a hash collision exists".

## Review surface and statement lock

The **review surface** is what a reviewer must read to know what H1–H4, their deployed-history
forms (`Headlines.deployed_claims`, `deployed_rollback_free` and `deployed_recoverability`), the
eight joint-premise witness theorems (from the six profiles under Joint-premise realizations),
the trap witness and its escape mean: their statements and every Etna definition they use, but
no proof. `review-surface.lock.json` records a SHA-256 of the kernel terms of each of those
constants (1,617 at this revision).
`python3 scripts/review_surface.py --check` fails if the lock is stale; the `etna-formal` job
runs it. Proof-only changes never touch the lock.

The `etna-review-surface` job (`formal--etna-review-surface.yml`) runs on
`pull_request_target`, so GitHub takes both the workflow file and the judge script from the
base branch. The pull request's commits are read as git objects only; nothing from them is
checked out or executed. The judge compares the lock and the gate files (`scripts/`, the
Python tests, the Lean regression files, the theorem manifest, both coverage maps, the
shadowing allowlist, the lakefile, the toolchain pin and the formal workflows) between the
merge base and the pull request head, and lists the changed constants
in the job summary. Any difference fails the job until a reviewer applies the
`formal-statement-change` label.

The label is an acknowledgement, not access control: anyone with triage rights can apply it,
and it stays through later pushes. What blocks a merge is the repository ruleset's code-owner
review with last-push approval; `/formal/**` and `.github/workflows/*` have code owners. After
applying the label, re-run `merge-gatekeeper`, which does not trigger on label events. The
pull request that introduces the judge is not judged by it, because its base branch has no
copy yet.

## Visual audit reader

`python3 scripts/generate_statements.py` writes `STATEMENTS.html`, a self-contained offline
reader inspired by [FlashProve's statements page](https://github.com/anthropics/FlashProve/blob/main/lean/STATEMENTS.html).
It is not tracked; CI uploads it as the `etna-statements` workflow artifact. It puts H1–H4
and their scope beside exact Lean source, lists the fields of all three premise records and
of `LiveAt`, and searches named declarations, reviewed theorem types and exact rule-evidence
edges. It is a source index, not a compiler-resolved dependency graph or a proof result.

## Current safety contracts

H1 derives one retained header/parent chain for all Etna signals, reachable authenticated
roots, actual execution-time landing suffixes, one-shot origin writing and start freezing.
For SPEC section 1's finality it derives that a later run without `rollback`
(`CheckpointRisk.RollbackFreeRun`) loses no retained signal and, after a landing, no retained
record and no checkpoint height (`CheckpointRisk.RollbackFreeRun.retains`), and that no
rollback meets `Governance.RollbackAuthorized`.
Ordinary Unzen proofs must strictly advance proposals and match their decoded boundary
parent to the stored finalized hash. The upstream header-extension primitive then derives
a monotone legacy frontier and strict separation of the legacy and Etna signals emitted by this modeled execution.
H1 also exports `SwitchingFence`: after a first Etna landing, retained legacy heights
are at or below the current start S and Etna heights are above S. The Unzen lane starts
with no legacy signals, zero finalized/checkpoint data and the configured nextProposal;
pre-deployment SignalService checkpoints are not represented.
Unzen proposal creation/DAO recovery and actual Unzen guest execution remain external.
While the checkpoint is still S, the model's `land` checks all three conditions of
LAND-6.1-8a: every Unzen proposal is finalized, the last finalized hash is the start hash, and
the SignalService checkpoint at S exists with the start hash and stateRoot. The Unzen record
keeps the height of the checkpoint that the last Unzen proof saved, and `land` compares it with
S, so a start written with the right hash and stateRoot at the wrong height is refused
(`tests/CurrentGuards.lean`). Before, the model compared only the hash and stateRoot. That gap
was in the model of `land`, not in H1: H1's root at S needs a hash-bound header at S, and equal
hashes of hash-bound headers mean equal heights (`currentPrimitives`).

H2 separates general historical identity/funding from normal at-risk accountability.
For an entire execution with no rollback since fresh deployment, and a physical candidate
chain above the current checkpoint whose checkpoint hash
matches the node's actual Inbox checkpoint, it derives snapshot monotonicity, the selection
cutoff bound, an issued/live/unconfirmed bond for every quorum-overlap member, and retention for the configured evidence window. **The deployment must separately
ensure a positive evidence window no longer than the immutable withdrawal delay
(PARAM-11-11).** This is an explicit deployment premise, not a contract initialization
check or a derived parameter choice. Bond status and snapshot/cutoff inequalities are
derived. H2 also exports retention of every member of a valid authenticated candidate
committee, independent of a particular overlap or round. Within the window, a liability has already exhausted its principal
or has an executable funded slash. The proof does not promise new collateral after a
previous punishment. Cross-round agreement additionally requires the declared honest
locking/minority, signature attribution and codec assumptions.

Exceptional verifier-failure rollback is outside that normal retention result. As
RECOV-8-35 states, money already withdrawn using a bad checkpoint cannot be recovered.
The modelled rollback truncates the retained signals, which are SignalService checkpoints.
The SignalService receive cache and Bridge messages left `RETRIABLE`, which RECOV-8-27a
makes the rollback upgrade invalidate until they are proven again, are not modelled.
A regression constructs that loss and rejects treating it as normal execution.
There is no restart theorem after a rollback; the normal guarantee then remains
inapplicable for that deployment. Under H1's premises no rollback is authorized, so an
authorized deployed history never contains one (`Headlines.deployed_rollback_free`). The
normal result covers heights above the actual checkpoint only. Historical liability also does not assert that legitimately withdrawn old stake remains
escrowed forever. Temporal agreement uses an actual closed common cutoff in one generation.

H3 derives exact FIFO intervals from complete closed journals, due-only skipping, early
position-zero inclusion from the complete decoded transaction list, actual proof-image
support for every selected ruleset, exact positive fees/refunds and pending recovery bounds.
Ordinary recovery preserves the checkpoint/records/head and constructs its exact new origin.
Import closes readiness/trust, preserves signing state and installs the original-generation
numeric header interval max(o, s − U + 1)..s, with U the unsettled bound (DATA-5.4-4). For
s > o its decoded inspection rejects a validator-state preimage that the adapter reports as not
hashing to the landed value, and halts on an authenticated validator-state contradiction
(DATA-5.4-5). At s = o the import takes the 8.4 genesis path (DATA-5.4-1) and those three
checks do not apply. Actual EL header
contents/indexes, earlier ancestor context, the window's Comet history and stock stores
required by SPEC 5.4 remain an explicit abstraction gap.

Checkpoint records, cuts, `LandInput` and the statement carry appendix A's validator-state
hash as an opaque atom. The frontier leaf, the landed record, the statement endpoints and the
node trust check compare it. Unlike the EL hash (bound by the header hash) and the Comet hash
(bound by signed commits), nothing in `Blocks.Valid` constrains its value: H2's "valid chains
agree" covers it only through `currentCodec`, and a landing's value is certified only through
`currentVerifierSound`. CometBFT's state-update arithmetic behind it (PROOF-6.2-41a) and the
preimage encoding (ENC-A-29a) are not modelled.

The spec's start-height exception (PROOF-6.2-40, SYNC-9-5) is not modelled; in the model it
is unobservable. At a generation's origin the model labels the origin header with the
record's stored value, so the origin always compares equal to itself. In the real system the
start-height state is the one CometBFT builds from the generation's genesis, which differs from
the record: the record holds 0 at S and the old generation's value at a recovery origin. Three
implementation obligations therefore stay outside these proofs:

1. The guest builds the start-height validator state from the generation's genesis, not from
   the origin record's preimage (PROOF-6.2-41a).
2. The node does not compare the validator-state hash at the current generation's start
   height (SYNC-9-5). A client that transcribed `nodeTrust` literally would halt after every
   recovery, until the new generation's first landing moves its trust target.
3. An import at s = o takes the 8.4 genesis path (DATA-5.4-1). The model only skips the three
   validator-state checks there; it does not model the genesis path.

At other heights the node compares the landed value with the validator state it recorded when
it committed that height in the current generation, never stock CometBFT's historical lookup
(SYNC-9-5c). The model reads the node's own header value, so where that value comes from is a
fourth implementation obligation.

The [PR #22348 alignment](reports/alignment-22348.md) records the latest re-pin. The
[PR #22341 alignment](reports/alignment-22341.md) records the previous re-pin and the H1
restatement. The [PR #22338 alignment](reports/alignment-22338.md) records the changed clauses, evidence
and boundaries.

The current registry admits `0 ≤ slashBountyBps < 10000`; zero pays no reporter
bounty. Slashing pays `floor(balance * slashBountyBps / 10000)` to the authenticated
caller, including a self-reporting owner, and the remainder to the fixed sink.
The executable-slash premises use the strict bound. The [PR #22335 alignment](reports/alignment-22335.md) records the authority
changes and the unchanged deferred derivation, finality and DAO implementation boundaries.

## Reference and archive authority

Reference hashes bind the complete supplied closed L1 prefix, including Inbox balances.
A certificate's archive is a hash-bound physical parent chain from the authenticated
origin through its actual batch parent and actual blocks. Its anchors and derived selection
snapshot cannot exceed the reference. The obsolete `archiveAuthenticated` field is removed; concrete conditions are
mandatory for certificates and node replay.

The semantic certificate still requires complete origin-to-parent ancestry. This is a
stronger input domain than PROOF-6.2-13's at-most-L+2 historical-header guest budget. A
bounded ordinary decision-window extraction is checked separately; no theorem yet refines
the complete accepted-certificate interpreter to an L+2-only guest. That implementation
and completeness gap remains deferred, including separate L1 ancestry/recovery material.

Pure `Certifies` uses only that immutable reference view. General transport theorems prove
reuse under equal statements and bound prefixes. Applying it to a live World additionally
uses a storage footprint (configuration, parameters, start and closed registry prefix)
that is now derived from actual deployment history and the pure certificate's generation
binding. It is absent from `ImageCertifies` and from verifier soundness. Raw `Trace ∧ land`
alone is insufficient: an unsound verifier can accept a stale pre-recovery reference. The
operational theorem therefore uses pure verifier soundness, actual trace and fresh registry
provenance, then derives the footprint, committees and per-block validation. Equality of a statement alone does not grant arbitrary live-world compatibility.
Tests close a later changed block and exercise actual `take` truncation, as well as reachable
rollback followed by another accepted landing.

## DAO upgrade and deployment scope

`Trace` specifies admissible decoded operations. `correctStart` and verifier rollback
represent DAO implementation upgrades, not public Solidity functions that can read the
ghost fields `everLanded` or `activeSnapshots`. `Governance.DeployedTrace` exposes raw
upgrade execution; a separate **per-history** `AuthorizedUpgrades` condition records the
historical correction/restore duties. `Headlines.deployed_claims` derives initialized
endpoint claims through that explicit refinement, and `Headlines.deployed_recoverability`
derives H4 the same way. Owner identity alone is insufficient.

A rollback's duty is `Governance.RollbackAuthorized` (RECOV-8-24 to 8-28). A retained record
is **trusted** when some admissible history certifies it (`Custody.Certified`) or it is the
current start record (`Custody.Pending`); otherwise a **bad** landing wrote it. The duty
requires the target to be a retained record restored with the snapshot saved with it, every
retained record at or below it to be trusted, and the first retained record above it to be
bad. So a verifier failure happened, and the target is the last trusted landing, or the start
record if no landing is trusted (RECOV-8-28). It cannot be a guard of `rollback` itself,
because `Certified` quantifies over `Trace`, which `rollback` builds.
`Governance.rollback_target_unique` shows that the duty leaves no choice of target height,
and `Governance.authorized_rollback_restores` shows the effect: the checkpoint, FI head and
snapshot become the target's, and only trusted records stay. `Headlines.deployed_rollback_free`
shows that under H1's premises an authorized deployed history from a fresh deployment never
executes a rollback, so H2's rollback-free results apply to it. Judging a landing by the record
it wrote is a model choice: a bad landing whose record happens to be certified (its signal's
state root is not judged) counts as trusted unless a bad record lies below it.

The main profile starts with raw empty `RegistryMachine.Genesis`. It does not cover the
existing-registry retarget opening in START-10-16a. Seeded identity/funding preservation
helpers accept a separately verified nonempty opening; they do not create its historical
provenance or prove that deployment procedure.

## Joint-premise realizations

All fifteen primitive/deployment premises hold together in independently checked profiles,
and `NonVacuity.CurrentRecovery` (a new network) and `NonVacuity.CurrentRecoverySwitch` (a
switching network) add H4's five. Their restrictions are part of the evidence, not production
implementations:

| Profile                            | Nonempty conclusion                                                                                                                                                                                                                                                                      | Deliberate restrictions                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| ---------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `NonVacuity.Current`               | Paid registration/FI, accepted landing, recovery then generation-1 landing, reachable rollback then landing, and a snapshot import above the origin after the first landing (`windowed_import_satisfiable`)                                                                              | One funded key, ruleset 0/image 11, two static statement templates and two authenticated votes; the Unzen adapter refuses and the import adapter accepts every candidate; base engine is not honest. It does not positively exercise conflicting quorums or agreement.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| `NonVacuity.CurrentSwitch`         | Actual legacy proof, recovery into generation 1 before the first Etna landing, disjoint legacy/Etna checkpoints and paid FI advancement                                                                                                                                                  | Fixed upstream proposal set and one legacy proof; `UnzenExtension` has no true antecedent in this profile; one static Etna statement/image, ruleset 0; import refuses and base engine is not honest. No running Unzen implementation or complete switch rehearsal.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| `NonVacuity.CurrentRisk`           | Real paid stake and conflicting quorums above the genesis checkpoint; at-risk overlap and successful decoded import with readiness/trust false                                                                                                                                           | L1 proofs and EL catalogue refuse; Byzantine engine; fixed key/votes/parameters. Import adapter accepts decoded authenticated flags; only numeric header publication is represented. It does not demonstrate EL landing, post-landing snapshot derivation or real stores.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| `NonVacuity.CurrentAgreement`      | All fifteen premises, honest locking/attribution/minority, and agreement of a nonempty valid chain with itself                                                                                                                                                                           | Same restricted base environment; separate all-honest single-value round-0 engine. It is a decoded execution normalization, not a production CometBFT refinement; no distinct chain inputs or later-round unlock is positively exercised.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| `NonVacuity.CurrentRecovery`       | All fifteen premises and H4's five, a reachable initialized world that meets `LiveAt`, and H4 applied there: an accepted landing after one plain recovery (`live_recovers`)                                                                                                              | New network only: `initializeInbox` writes S = 0, and `setOrigin`, `correctStart` and `unzenProve` are not exercised; K = 1, so the landed segment is one block; c = S = 0 is on the grid, so `LiveAt` holds by `LiveRules`' first case and the path's structural branch is not exercised; one online key that signs every vote; one catalogue definition for every ruleset, and every image implements only ruleset 0; the ruleset's execution check reads only the header's two hashes, and its payload check accepts every transaction list and witness bytes; the classical verifier described below; an engine that attributes every precommit; a payload check that accepts any one to six blobs. The forced-inclusion queue is empty. Nothing has landed in the reachable world, so the conclusion's above-the-checkpoint part is not exercised. A switching network is `NonVacuity.CurrentRecoverySwitch`. |
| `NonVacuity.CurrentRecoverySwitch` | All fifteen premises and H4's five on a switching network, a reachable initialized world that meets `LiveAt` before any Unzen proof, and H4 applied there (`live_recovers`): the path proves the Unzen lane, and its first landing passes the first-landing fence, height check included | `NonVacuity.CurrentRecovery`'s environment with the switching fields set, so that profile's restrictions apply except the new-network ones: `setOrigin` writes S = 5 from a hash-bound legacy header whose timestamp is before `forkTime`, and the path runs `unzenProve`. One legacy header and one valid proof, of the final proposal 1; `unzenParent` returns the empty lane's finalized hash 0, so `UnzenExtension` has no true antecedent in this profile (no hash-bound header has EL hash 0), as in `NonVacuity.CurrentSwitch`; the written start equals the Unzen final header, so `correctStart` is not exercised; c = S = 5 is on the K = 1 grid, so `LiveAt` holds by `LiveRules`' first case and the path's structural branch is not exercised. No Unzen implementation runs, and nothing has landed in the reachable world.                                                                           |

Header/state/prefix commitments in these profiles have globally injective structural Nat
interpretations. They are ideal models, not fixed-width Keccak implementations. Their
verifiers are fixed functions of proof inputs/statements, with global reachable-world
soundness proofs. No verifier is an oracle for a desired World or headline outcome.
The verifier of `NonVacuity.CurrentRecovery` and `NonVacuity.CurrentRecoverySwitch` is an
ideal sound and complete checker: a proof of image I for statement d is accepted exactly when
I certifies d over the L1 prefix that d's reference hash commits to, decided classically;
version, backend and proof bytes are ignored.
It decides certification of the statement, not a desired World.
All positive accepted certificate fixtures use empty prebatch `prior` lists. None
positively exercises a nonempty archive prefix or ordinary L+2 cutoff selection.
The accepting, switching, equivocation, import, honest-agreement and both joint H1–H4 contracts,
and the rollback grid trap and its escape, are mandatory audit obligations. Finite ordinary
fixtures using fewer premises are not substitutes.

## Exact traceability and deferred scope

`rule-coverage.json` names each reviewed rule/theorem edge. Shared paragraphs do not give
neighboring rules evidence. Supporting guards are separate; generic conservation, list,
encoding and transport helpers have no protocol source credit. A narrow partial fragment
never verifies the entire rule. Thirty-four shared declarations outside the `Current`
namespace are listed as unsourced plumbing in `scripts/check_spec_coverage.py`: twenty lemmas
the current proofs reuse, and fourteen semantic pins (`EtnaProofs/Contracts.lean` and
`Consensus.election_valid_iff`) that fail the build if a shared definition the statements use
is weakened without editing its pin.

The inventory is **60 partial / 508 deferred clauses**, and **43 narrow partial /
37 supporting / 528 deferred binding rules**, plus 32 deferred assumption/limitation rows.
SWITCH has narrow first-fence/root evidence. All 93 ANCHORLESS and 47 ACCEPTANCE
clauses remain deferred. Margin arithmetic, bridge resolver/EIP-4788/storage migration,
production parsing/crypto/EL/guest/token/Solidity/Comet/store refinement, operational
availability, measured resources and full launch/switch/recovery acceptance remain separate.

`testdata/etna_current_conformance` holds vectors generated by the current executable model
(`lake exe etna-vectors --write <dir>`); implementation harness adoption is not claimed.

## Verification

Use pinned Lean 4.35.0, Init/Std only. From `formal/etna`, run serially:

```sh
python3 scripts/lint_sources.py
python3 scripts/check_imports.py
python3 scripts/check_spec_coverage.py
python3 scripts/rule_coverage.py --check
lake build
python3 scripts/check_current_vectors.py
python3 scripts/review_surface.py --check
python3 scripts/generate_artifacts.py
python3 scripts/generate_artifacts.py --check
python3 scripts/audit_proofs.py
python3 -m unittest discover -s tests            # fast suite
ETNA_FULL_TESTS=1 python3 -m unittest discover -s tests   # adds the slow mutation suite
```

The audit checks exact types, mechanical roles, allowed transitive axioms, premise use,
mandatory joint-premise profiles and fresh whole-kernel replay.

CI runs three jobs. `etna-formal` (`.github/workflows/formal--etna.yml`) runs every gate
above with the fast suite on each pull request, with a Lake build cache. `etna-review-surface`
needs no Lean: it applies the statement lock against the base branch. `etna-formal-full`
(`formal--etna-full.yml`) runs the full mutation suite and `lake check --paranoid` (five
independent kernels in a bubblewrap sandbox) nightly, on pushes to main, on manual dispatch
and on pull requests labelled `formal-full`. Before the kernels it adds a 16 GB swap file and
logs memory and swap use every 30 seconds.
