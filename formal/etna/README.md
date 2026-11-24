# Etna design verification

The current authorities are `SPEC.md`, `ACCEPTANCE.md`, `ANCHORLESS.md` and `SWITCH.md`
under `packages/protocol/docs/etna` at [PR #22425, `b01356ddc`](https://github.com/taikoxyz/taiko-mono/commit/b01356ddc942ee10e67d1f506bf4acd043b8686c).
The exact authority hashes and current rule evidence are recorded in
[`current-coverage.json`](current-coverage.json) and [the rule coverage report](reports/current-rule-coverage.md).

## L2 staking specification

- [`L2Staking`](EtnaModel/L2Staking.lean) models immediate seat admission and exit, delayed
  withdrawal, double-sign slashing, DAO forfeiture, consecutive misses and the post-penalty
  snapshot. Decoded vote identities distinguish empty hashes from present zero hashes.
  Token calls and canonical vote encoding and verification are execution adapters.
- [`PerBlockCommittee`](EtnaModel/PerBlockCommittee.lean) decodes the 29-byte header field
  and the parent LastCommit miss bitmap. It validates all 128 candidate seat records, reads
  the full snapshot height and selects either the candidate or the L1 fallback. The uint256
  maximum forces fallback independently of L2 stake. The origin's fallback signs the first two
  blocks, and block H determines the signers of H+2.
- [`PerBlockGuest`](EtnaModel/PerBlockGuest.lean) models the decoded validator openings at a
  landing's proof origin and checks the required commits at the terminal height and at
  signing-set changes. Its proof-origin anchor supplies only the two fallback settings for
  p+2. L1 ancestry and EL and Comet header authentication are adapter boundaries.
- [`L2StakingProtocol`](EtnaModel/L2StakingProtocol.lean) connects the parent staking state and
  block-start transition to validator updates. Reverted and no-code calls preserve staking
  state, while an EL execution fault prevents the transition. The model also covers origin
  recording in plain recovery, the U range (1 to 262,144, target 151,200), the withdrawal-delay
  bound and strict quorum overlap. The quorum lemma concerns voting power. Fallback signing power carries no guarantee
  of slashable collateral.

Cryptographic authentication, block-start gas and receipts, and refinement to the contracts,
client or proof guests remain external. The current Lean modules cover decoded transitions and
their local properties. The root-only SignalService and the switching multisig's origin latch
and subsequent node and guest checks are outside this projection. An end-to-end landing,
forced-inclusion, checkpoint or recoverability theorem over the complete L2 staking design
remains open. The current specification treats
unbacked L2 TAIKO and false landings separately. An accepted landing can still permit an
unbacked token withdrawal through the bridge.

## Historical L1 registry verification

The remaining sections describe the historical H1–H4 machine and its reviewed proof and fixture
suite. Lean declaration and fixture names retain their original `Current` names. Their evidence
and assumptions refer to the [#22422 revision](https://github.com/taikoxyz/taiko-mono/pull/22422).
The archived 2026-10-30 model is available at
[`583bc2620`](https://github.com/taikoxyz/taiko-mono/tree/583bc2620258838e75ce353c11f9344616ac1020/formal/etna).

The authority checks read historical documents from the #22422 merge commit and current documents
from the checkout. Use a clone with Git history available for these checks. Spec-only pull
requests skip the formal jobs, and the nightly job reports drift against the current hashes.

### Historical claims

The L1 registry proofs give **conditional, design-level safety and recoverability** for the
decoded #22422 machine. Exact claims live in `EtnaStatements/Current.lean` (276 lines); composition is in
`EtnaProofs/Headline/Current.lean`. Every claim holds for every reachable `Trace` from a
fresh deployment under explicit premises: **H1 assumes the five fields of `FundPremises`;
H2 and H3 assume all fifteen fields of `Premises`**, which extends `FundPremises`; **H4
assumes `RecoveryPremises`**, which extends `FundPremises` with six more fields, and the
seven per-state hypotheses of `LiveAt` (below).

- **H1, fund safety.** Every accepted landing extends one hash-bound checkpoint chain from an
  authenticated root; Etna and legacy (Unzen) signals stay disjoint; the start is written once.
  None of H1's five premises concerns consensus (signature soundness, codec, vote attribution
  or honesty), so H1 holds whatever the committee signs. This is the formal form of SPEC
  section 1's statement that even a committee acting maliciously as a whole cannot take funds
  on L1. H1 also states SPEC section 1's finality of checkpoints: every later run without a
  `rollback` keeps each retained signal and, once something has landed, each retained landing
  record and a checkpoint at least as high; and no rollback is authorized, because a rollback
  needs a bad landing (a verifier failure) and under H1's premises there is none. It covers the
  bridge's read path too (RECOV-8-27a): with the L1 `SignalService` and Bridge run alongside,
  every signal cached as received and every message left `RETRIABLE` was proven against the
  state root of a checkpoint the L1 `SignalService` still holds (`Bridge.run_backed`).
- **H2, accountable finality.** Two conflicting commits at the same height and round imply an
  overlap of more than one third of the voting power with authentic evidence and an executable
  funded slash; with honest locking and a Byzantine minority, valid chains agree.
- **H3, forced-inclusion integrity.** No valid landing passes over a due forced inclusion: FIFO
  service, due-only skips, no early skip, and only `land` advances the head. This is a safety
  property of landings. It does **not** promise that a due inclusion is ever landed.
- **H4, recoverability.** From every reachable, initialized state that meets `LiveAt`, some
  sequence of modelled calls with no `rollback`, no forced-inclusion blanking and no structural
  upgrade reaches an accepted `land`. Its one recovery is plain and excludes the members that
  `LiveAt` names, so it covers a committee that is live only once offline members are excluded; if anything had landed before,
  that landing ends above the starting checkpoint. A landing may end at any height above the
  checkpoint c, so the path lands one block, c + 1, from wherever c is.
  After a real verifier failure, H4's premises fail and it says nothing. L2 block production
  is constructed, not assumed: the proof builds the valid block and its certificate from
  hypotheses about execution, signing and data availability. Proof completeness
  (MODEL-1-1/1-2) is a premise, so it is assumed, not shown. The
  [recoverability report](reports/recoverability.md) explains the path, each premise and
  hypothesis.

Not covered here: normal-operation liveness (landings continue without governance);
adversarial scheduling, since H4's path is one that exists when every caller cooperates; the
DAO's recovery policy in SPEC 8.1 (when to recover, and the checks before it), since H4 shows
that the recovery mechanism works from every such state, not that the DAO should use it there;
recoveries with blanking, and structural upgrades; recovery after a verifier failure, even once the verifier is replaced, since H4's
premises assume a sound verifier; refinement to the Solidity contracts, the Rust client or the
zkVM guests; CometBFT's implementation, cryptography, data availability, and economic
security. Cross-round equivocation (amnesia) is outside H2, as the spec states.

## Terms

Some of the model's names are not the spec's words. Renaming a definition that the headline
statements use changes the statement lock and hand-reviewed gate files (see Review surface and
statement lock), so the names stay and this section maps them to `SPEC.md` at the pin above.

Headlines and the bullets of SPEC section 1:

- H1, fund safety (`FundSafety`): the "Funds" bullet. It also carries the second sentence of the
  "Finality" bullet: nothing at or below a checkpoint is rolled back, except by a DAO upgrade
  after verifier failure.
- H2, accountable finality (`AccountableFinality`): the first sentence of the "Finality" bullet
  (a commit is final while Byzantine voting power stays below 1/3) and the same-round
  double-signing part of "Slashing scope".
- H3, forced-inclusion integrity (`ForcedInclusionIntegrity`): the "Censorship resistance"
  bullet.
- H4, recoverability (`Recoverability`): no section 1 bullet. It is about the governance
  recovery of SPEC section 8. It is not the "Liveness" bullet, which this package does not prove.
- `ProtocolFinality.H2` (`EtnaModel/CurrentProtocolFinality.lean`) is not headline H2. It is a
  per-state proposition, same-round paid accountability together with chain agreement, which
  `ProtocolFinality.current_h2` proves under honest executions. Headline H2's proof uses only
  its agreement half.

Committees and the registry:

- "election" (`Committee.election`, `Consensus.ElectionValid`): the spec's selection (SPEC 4.3,
  "One selection rule"). The spec never says "election".
- "cutoff" (`Committee.Record.cutoff`, `Finality.cutoff`): the spec's selection snapshot, an L1
  block number. In the spec the word survives in the names `genesisCutoff` and `cutoffL1Block`.
- `RegistryHistory.Snapshot`, `recordSnapshot`, `latestSnapshot`: the spec's registry
  checkpoint (l1Block, count, entriesRoot; STAKE-4.1-36), with the entries themselves in place
  of their count and root. So here the model's "snapshot" is the spec's checkpoint, and the
  spec's snapshot is the model's cutoff.
- `State.snapshot`: the spec's `activeCommitteeSnapshot` (slot 284).
- Other uses of "snapshot": `Protocol.Snapshot` is the modelled L1 state at the end of one L1
  block (`World.history`); `ValidatorState.Snapshot` is appendix A's validator-state payload at
  one height; `Call.importSnapshot` is the spec's checkpoint import (SPEC 5.4).
- `Signer.State.retired`: the generations a signer has left, which the spec calls superseded
  (RECOV-8-14).

Checkpoints and records:

- `structure Checkpoint` (`EtnaModel/Common.lean`): the spec's slot 285 landing record.
  `State.records` is slot 285 itself. `State.checkpoint` is the record at the height of the
  spec's `lastCheckpoint`, which stores only the height and the EL hash (slots 270/271).
- `structure Signal`: the spec's SignalService checkpoint (height, hash, stateRoot).
  `State.signals` are those the Inbox saved; `World.legacySignals` are those the Unzen Inbox's
  proofs saved.
- `structure LandingRecord` (`EtnaModel/CurrentProtocol.lean`): ghost provenance of one landing,
  namely its input and the Inbox and L1 history before the call (`World.activeLandings`). It is
  not the spec's landing record, which is `Checkpoint`.
- `World.start` (`StartData`): the Etna start S with its hash and stateRoot (slots 272 to 274).
  The spec's storage name for S is `genesisHeight`.

"Origin" has four senses in the model:

- The fixed origin record of slot 290 (RECOV-8.4-3): `Etna.Design.Origin`, with `State.origin`
  for the current generation and `State.origins` for every generation. `originHeight` and
  `originBlock` (`Finality.Config`, `Consensus.Context`) are its startHeight and its
  l1BlockNumber, the spec's L1 origin. `Start.Origin` is a second copy of the same record, used
  by the standalone start machine `Start.State`.
- The proof origin p (`LandInput.parentHeight`): the local `origin` in `Protocol.statement` is
  p's slot 285 record.
- The slot 285 record at the current generation's start height: `certificateOrigin` and
  `certificateOriginCut`.
- The start write (START-10-5a): anyone can call `setOrigin(S)` after the Unzen proposal cutoff
  and fork time. It latches the finalized hash and state root read at S.
- `enqueue` is `saveForcedInclusion`, `sweep` is `sweepProtocolFees`, `invalidate` is
  `invalidateRecoveryNonce` and `unzenProve` is the Unzen Inbox's `prove`.
- In the registry, `confirm` is `confirmExit`, `slash` is `slashDoubleSign`, and `exclude` is the
  `forceExit` that `recover` calls for its exclusion list (RECOV-8-41, RECOV-8.3-16).
- `clear` (`RecoveryRequest.clear`, `Forced.clear`): the spec's `fiToClear` and blanking
  (RECOV-8-43, RECOV-8-44).
- The spec describes these steps but gives them no function name: `initializeInbox` (Inbox
  initialization, START-10-5), `rollback` (the verifier-failure rollback, RECOV-8-27) and the registry's
  `recheck` (that rollback's re-check of exit confirmations, STAKE-4.1-29).

Words the spec does not use, or uses for something else:

- "World" (`Protocol.World`): the model's whole state. It holds the Inbox, the registry and its
  token, the forced-inclusion queue, the Unzen Inbox's state, the rules schedule, the verifier
  and images, one node, the L1 block number and ghost history.
- "journal": the World's record of what has happened: every forced inclusion ever admitted
  (`World.queue`), one `Protocol.Snapshot` per closed L1 block (`World.history`) and the retained
  landings (`World.activeLandings`). `Journal.Invariant` states its shape.
- "catalogue" (`Blocks.RulesetCatalogue`, `Environment.catalogue`): for each ruleset number, its
  published definition (SPEC 10.1, START-10.1-3a).
- "Unzen lane", "legacy": the Unzen Inbox's side of the L1 SignalService on a switching network:
  its proofs (`unzenProve`, including the Inbox's forwarding of their checkpoints, START-10-5),
  its state (`World.unzen`) and the checkpoints it saved (`World.legacySignals`). The spec says
  "Unzen Inbox" and uses "legacy" only for transactions.
- "archive": the current-generation EL headers, from the generation origin through the batch,
  that a certificate carries and committees are derived from (`Archive.Authenticated`). In the
  spec an archive is retained history (SPEC 5.3, 9.1); its nearest words here are the
  "historical headers" of PROOF-6.2-13.
- "certificate", "certifies" (`BatchCertificate`, `Certifies`, `ImageCertifies`): what a sound
  proof establishes about a statement: a valid batch of blocks, with its archive, that has
  this statement. The spec says a sub-proof "authenticates" the statement (PROOF-6.2-9). A
  certificate is not a CometBFT commit, which the model also calls a commit
  (`Consensus.CommitValid`).
- "custody" (`Protocol.Custody`): the chain of accepted landings, from an authenticated root
  (the genesis block or the Unzen start), that stands behind a checkpoint (`Custody.Path`,
  `Custody.Coherent`).
- "fence": `Start.firstLanding`, `Protocol.firstFence` and `Custody.FirstFence` are the spec's
  Unzen start check (LAND-6.1-8a), and `Custody.SwitchingFence` is the separation of Unzen and
  Etna checkpoint heights at S that follows from it. The spec's "checkpoint fence" is something
  else, the forkchoice `finalized` hash of SYNC-9-3; the model's comments call that one the
  forkchoice fence (`CheckpointRisk.Candidate`).

Smaller names:

- `unsettled`: U, the unsettled-block limit. `AnchorValid.pressure` is back-pressure
  (CONS-3.4-6, SPEC 6.4).
- `forcedETH`, `Forced.extraETH`: force-sent ETH (FI-7.1-9). It is unrelated to forced
  inclusion, unlike `forcedDelay`, `forcedFee` and `forcedThreshold`.
- "skip": as in SPEC 7.2, a legal skip consumes a due entry. Leaving a due entry unconsumed is
  not a skip.

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
| `currentVerifierSound`      | Every accepted landing proof with a sound backend certifies its statement for the selected rulesets, with a verified commit for every block      | Etna zkVM/TEE guests, proof systems, `ZkRequiredVerifier`, DAO verifier choice |
| `currentReferenceBinding`   | Equal L1 block hashes imply equal L1 prefixes                                                                                                    | Hash collision resistance (modeled as an injective map)                        |
| `currentRegistryGenesis`    | The registry starts fresh, with no prior identities or history                                                                                   | Deployment procedure                                                           |
| `currentUnzenExtension`     | A valid Unzen proof extends its decoded parent to a higher height                                                                                | Existing Unzen guest                                                           |
| `currentStandardToken`      | The bond token behaves as a standard ERC-20 transfer                                                                                             | Token deployment                                                               |
| `currentSignatureAgreement` | Signed consensus bytes refine to the registry's signature check                                                                                  | Comet sign-bytes in the Rust client and the Solidity verifier                  |
| `currentBountyBound`        | `slashBountyBps < 10000`                                                                                                                         | Registry initializer (checked on chain)                                        |
| `currentCodec`              | Comet header/envelope codec is canonical, and a valid block's Comet hash and parent fix its whole header                                         | Rust client and stock CometBFT parity; CometBFT's deterministic state update   |
| `currentVoteAttribution`    | Every commit vote is attributed to a real precommit of the fixed engine                                                                          | CometBFT engine and validator operation                                        |
| `currentClock`              | L1 time strictly increases with block number                                                                                                     | Ethereum L1                                                                    |
| `currentCatalogueHash`      | Catalogued EL transaction bytes hash to the environment's transaction hash                                                                       | Hash function; EL catalogue                                                    |
| `currentSignatureSound`     | An accepted signature authenticates the key holder                                                                                               | secp256k1 verification in Solidity                                             |
| `currentSelfAllowance`      | The registry has no allowance to itself at genesis                                                                                               | Token deployment                                                               |
| `currentEvidenceWindow`     | `0 < evidenceWindow ≤ withdrawalDelay`                                                                                                           | Deployment parameters                                                          |

H2's chain-agreement clause additionally assumes `ProtocolFinality.HonestExecutions`.
This separate antecedent supplies honest local locking rules and a Byzantine minority at
the checked heights.

`currentVerifierSound` is stronger than what a guest checks. Under PROOF-6.2-16/17 a guest
verifies the commit of h and of the last block each committee signs in (p,h]; every other
block of (p,h) is covered as an ancestor, through its last_block_id links, of a block whose
commit is verified against the same committee. The model keeps a verified commit for every
block in block validity (`Blocks.Valid.commit`), so a certificate, and with it this premise,
requires one for every block of the batch. H2's chain agreement also rests on that
every-block commit: it compares valid chains under the same validity relation. No theorem
shows that the guest's sparser check implies the every-block one.

H4's record, `RecoveryPremises`, extends `FundPremises` with the six fields below. The first
two repeat `currentClock` and `currentCatalogueHash`, so that each headline names exactly
what it rests on. The audit requires H4's proof to read every field of `RecoveryPremises`.
H4 depends on neither `Premises` nor any honesty or vote-attribution definition.

| Premise field           | What it assumes                                                                                                                                                                                                                                                                                                   | Who must make it true                                                                                                               |
| ----------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| `recoveryClock`         | L1 time strictly increases with block number                                                                                                                                                                                                                                                                      | Ethereum L1                                                                                                                         |
| `recoveryCatalogueHash` | Catalogued EL transaction bytes hash to the environment's transaction hash                                                                                                                                                                                                                                        | Hash function; EL catalogue                                                                                                         |
| `proofComplete`         | One verifier version accepts, for every statement an image certifies, two proofs of that image, at least one of them ZK (MODEL-1-1/1-2)                                                                                                                                                                           | Etna zkVM/TEE guests and provers within their resource limits; the DAO's verifier choice                                            |
| `payloadLive`           | At most one block of at most 124,000 bytes fits in one to six blobs that the payload check accepts                                                                                                                                                                                                                | Blob encoding and Ethereum data availability                                                                                        |
| `unzenStart`            | On a switching network, every header that a valid proof of the Unzen Inbox's final proposal authenticates is a usable Etna start: nonzero height, hash and state root, room for one more height, a state root that passes the start-implementation check, and a hash-bound start header with Etna's zeroed fields | The switching deployment (the Etna L2 `SignalService` implementation in place at S, PROOF-6.2-46a, SWITCH.md); existing Unzen guest |
| `referenceReadable`     | A complete closed L1 prefix has a nonzero reference hash                                                                                                                                                                                                                                                          | L1 block-hash adapter                                                                                                               |

H4 also takes `LiveAt`, seven conditions on the starting state rather than on the
environment. The audit requires H4's proof to read each of them too. c is the checkpoint
height.

| `LiveAt` field | What it assumes about the starting state                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         | Who must make it true                                                                                                          |
| -------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| `generation`   | generation + 2 < 2^48                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            | Counter headroom; no realistic deployment exhausts it                                                                          |
| `nonce`        | recoveryNonce + 1 < 2^256                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        | Counter headroom; no realistic deployment exhausts it                                                                          |
| `rules`        | nextRules + 1 < 2^48                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             | Counter headroom; no realistic deployment exhausts it                                                                          |
| `height`       | c + 1 < 2^48                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     | Height headroom; no realistic deployment exhausts it                                                                           |
| `window`       | A later L1 block R, with room in 48 bits, whose time is more than one second past each of: the current L1 time plus the largest `maxAnchorAge`, `forkTime`, and the genesis timestamp; at R the election succeeds and online keys that sign every vote hold more than 2/3 of the elected power (`CommitteeLive`)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 | Ethereum L1; the deployer (a genesis timestamp and `forkTime` that L1 reaches); online validators; eligible stake (LIMIT-12-6) |
| `ruleset`      | Either the active and next rulesets are live and share an image, and the path's recovery keeps them; or ruleset nextRules + 1 is live and has an image, and the path's recovery installs it as the current rules (LIMIT-12-21). A live ruleset's EL builds a valid empty child of every parent for every FI cursor, later timestamp, anchor and witness bytes (a forced transaction's raw bytes, or none) a block producer picks, and each canonical forced transaction of at most 8,192 bytes either executes at position zero or its single-transaction trial completes empty. Valid means the execution and payload checks accept, at those witness bytes, every block body that names the parent's hash, pays a fee share of 100 and carries the anchor's state root as its parent beacon root, the body fields the EL reads | Ruleset EL and guest images; the DAO and validators for rule upgrades (LIMIT-12-21)                                            |
| `unzen`        | On a switching network, the Unzen lane has finalized its last proposal, or a valid proof of that proposal exists from the current lane state                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     | Unzen provers and the existing Unzen guest (LIMIT-12-9)                                                                        |

Hash premises are a standard idealization: the models treat commitments as injective. Read a
claim that relies on them as "the claim holds, or a hash collision exists".

## Review surface and statement lock

The **review surface** is what a reviewer must read to know what H1–H4, their deployed-history
forms (`Headlines.deployed_claims`, `deployed_rollback_free` and `deployed_recoverability`), the
eight joint-premise witness theorems (from the six profiles under Joint-premise realizations)
mean: their statements and every Etna definition they use, but no proof. `review-surface.lock.json` records a SHA-256 of the kernel terms of each of those
constants (1,730 at this revision).
`python3 scripts/review_surface.py --check` fails if the lock is stale; the `etna-formal` job
runs it. Proof-only changes never touch the lock.
The validator-state H+2 theorem (`ValidatorState.hplus2`) is an additional root, so the
CometBFT arithmetic it uses is locked, although H1–H4 do not use it.

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
copy yet. Bootstrap is determined from the current target branch, not the merge base. If an
older branch predates the lock, its gate, lock or Lean source changes require acknowledgement;
docs-only changes still pass, and target-branch-only changes are not attributed to the PR.

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
`EtnaModel/CurrentBridge.lean` runs the SignalService receive cache and Bridge messages left
`RETRIABLE` alongside the protocol machine. RECOV-8-27a makes the rollback upgrade invalidate
them until they are proven again; the model's rollback step revokes them all (vector 27a.k),
and H1's last conjunct shows that this keeps every derived authorization backed by a held
checkpoint. Message values, fees, quotas and pausing are not modelled. The same module models
the L2 `SignalService`. A checkpoint write needs the syncer and a successful zero-root read
for the current block when beacon roots are enabled (`Bridge.saved_with_open_store`,
`Bridge.store_closed`). A held checkpoint takes priority at any time. With no checkpoint,
the L2 proof uses a nonzero EIP-4788 entry (`Bridge.root_prefers_checkpoint`,
`Bridge.root_beacon_fallback`). These L2 results stand apart from H1–H4.
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
s > o its decoded inspection rejects a preimage of valStateHash(s − 1) that the adapter
reports as not giving header(s)'s app_hash (DATA-5.4-3), and halts when the preimage's two sets
differ from header(s)'s validators_hash and next_validators_hash or the derived committees
differ (DATA-5.4-5). At s = o the import takes the 8.4 genesis path (DATA-5.4-1) and those three
checks do not apply. Actual EL header
contents/indexes, earlier ancestor context, the window's Comet history and stock stores
required by SPEC 5.4 remain an explicit abstraction gap.

Signing checks the requested generation and next height against the app's durable
boundary (SYNC-9-10). The boundary comes from verified checkpoint replay, durable
import or an authenticated application commit. Transport and WAL continuity are
adapter obligations.

Validator state is outside settlement (SYNC-9-5c, CONS-3.1-8): no checkpoint record, cut,
`LandInput`, statement or H1–H4 premise carries a validator-state hash, and the guest does
not check app_hash (PROOF-6.2-42). `EtnaModel/CurrentValidatorState.lean` is a separate
arithmetic model of the state the app commits in app_hash. It computes CometBFT v0.40.0
validator-set updates, signed proposer priorities, stored proposers, genesis initialization and
one priority increment per committed height. Its two-set pipeline implements H+2.
`genesisFor` derives the recovery initial committee from that generation's R snapshot;
old pending updates and old-generation priorities are not inputs. The proofs in
`EtnaProofs/CurrentValidatorState.lean` establish H+2 and per-height replay decomposition.
The update list omits members with unchanged keys and powers. The selected snapshot
activates even when the list is empty.
A source mapping, stock-Go reference vectors and scope details are in
[the validator-state report](reports/validator-state.md).

This model is not a restatement of H1–H4 and no headline uses it. The app's durable
SYNC-9-5c record, the appHash encoding (ENC-A-29b), raw key/address binding, the precise
ENC-A-29a ABI/Keccak encoder, the checkpoint import's derivation of the state after s, and
stock CometBFT store/Go implementation refinement remain separate obligations.

The [PR #22422 alignment](reports/alignment-22422.md) records the current re-pin and
the recovery-capacity, signer-height and rotation changes. The [PR #22419 alignment](reports/alignment-22419.md)
records the launch-hardening changes already included in #22422. The
[PR #22412 alignment](reports/alignment-22412.md) records the previous one, the
[PR #22410 alignment](reports/alignment-22410.md) the one before it, and the
[PR #22348 alignment](reports/alignment-22348.md) the one before that. The
[PR #22341 alignment](reports/alignment-22341.md) records an earlier re-pin and the H1
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

Inbox initialization checks the immutable registry minimum stake against the decoded
recovery capacity (START-10-14 and START-10-18). The environment supplies the capacity.
Measuring the deployed DAO, Inbox and registry path before refunds remains a launch gate.
The two-proposal Unzen switch and schedule-specific verifier rollout are governance procedures.

`Trace` specifies admissible decoded operations. `Governance.DeployedTrace` exposes raw DAO
verifier-failure rollback. The **per-history** `AuthorizedUpgrades` condition uses the retained
landing history and saved snapshots to authorize the restore. `Headlines.deployed_claims` derives initialized
endpoint claims through that explicit refinement, and `Headlines.deployed_recoverability`
derives H4 the same way. Owner identity alone is insufficient.

A rollback's duty is `Governance.RollbackAuthorized` (RECOV-8-24 to 8-28). A retained record
is trusted only through `Governance.TrustedRecord`: it has a certified header or is the
pending start, and every matching actual retained landing certifies its complete statement,
including the saved committee snapshot and emitted SignalService state root. Every non-start
record also needs an actual retained landing event. The ghost `activeLandings` journal stores
each call's input and pre-call Inbox/history; start writes clear it and rollback removes only
higher events. Matching a checkpoint certified in some other history cannot hide corruption
of the actual landing's metadata.

The duty requires the target and its saved snapshot to be retained, every record at or below
it to be trusted, and the first record above it to be bad. The target is therefore the last
landing before the first bad one, or the current start if none is trusted (RECOV-8-28).
`Governance.rollback_target_unique` fixes its height, and `authorized_rollback_restores`
shows that the checkpoint, FI head and snapshot become the target's and only lower records
stay. The duty remains external to the DAO upgrade, not a public contract guard.
`trace_trusted_records` derives actual-event provenance and complete certification from
execution and verifier soundness. `Headlines.deployed_rollback_free` uses it to show that an
authorized deployed history under H1's premises never rolls back. Metadata-only verifier
failures are tested separately; this does not add a general post-failure restart theorem.

The main profile starts with raw empty `RegistryMachine.Genesis`. It does not cover the
existing-registry retarget opening in START-10-16a. Seeded identity/funding preservation
helpers accept a separately verified nonempty opening; they do not create its historical
provenance or prove that deployment procedure.

## Joint-premise realizations

All fifteen primitive/deployment premises hold together in independently checked profiles,
and `NonVacuity.CurrentRecovery` (a new network) and `NonVacuity.CurrentRecoverySwitch` (a
switching network) add H4's six. Their restrictions are part of the evidence, not production
implementations:

| Profile                            | Nonempty conclusion                                                                                                                                                                                                                                   | Deliberate restrictions                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| ---------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `NonVacuity.Current`               | Paid registration/FI, accepted landing, recovery then generation-1 landing, reachable rollback then landing, and a snapshot import above the origin after the first landing (`windowed_import_satisfiable`)                                           | One funded key, ruleset 0/image 11, two static statement templates and two authenticated votes; the Unzen adapter refuses and the import adapter accepts every candidate; base engine is not honest. It does not positively exercise conflicting quorums or agreement.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| `NonVacuity.CurrentSwitch`         | Actual legacy proof, recovery into generation 1 before the first Etna landing, disjoint legacy/Etna checkpoints and paid FI advancement                                                                                                               | Fixed upstream proposal set and one legacy proof; `UnzenExtension` has no true antecedent in this profile; one static Etna statement/image, ruleset 0; import refuses and base engine is not honest. No running Unzen implementation or complete switch rehearsal.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| `NonVacuity.CurrentRisk`           | Real paid stake and conflicting quorums above the genesis checkpoint; at-risk overlap and successful decoded import with readiness/trust false                                                                                                        | L1 proofs and EL catalogue refuse; Byzantine engine; fixed key/votes/parameters. Import adapter accepts decoded authenticated flags; only numeric header publication is represented. It does not demonstrate EL landing, post-landing snapshot derivation or real stores.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| `NonVacuity.CurrentAgreement`      | All fifteen premises, honest locking/attribution/minority, and agreement of a nonempty valid chain with itself                                                                                                                                        | Same restricted base environment; separate all-honest single-value round-0 engine. It is a decoded execution normalization, not a production CometBFT refinement; no distinct chain inputs or later-round unlock is positively exercised.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| `NonVacuity.CurrentRecovery`       | All fifteen premises and H4's six, a reachable initialized world that meets `LiveAt`, and H4 applied there: an accepted landing after one plain recovery (`live_recovers`)                                                                            | New network only: `initializeInbox` writes S = 0, and `setOrigin` and `unzenProve` are not exercised; the landed segment is one block, as in every H4 path; `LiveAt` holds by `LiveRules`' first case, so the path's rules replacement is not exercised; one online key that signs every vote; one catalogue definition for every ruleset, and every image implements only ruleset 0; the ruleset's execution check reads only the header's two hashes, and its payload check accepts every transaction list and witness bytes; the classical verifier described below; an engine that attributes every precommit; a payload check that accepts any one to six blobs. The forced-inclusion queue is empty. Nothing has landed in the reachable world, so the conclusion's above-the-checkpoint part is not exercised. A switching network is `NonVacuity.CurrentRecoverySwitch`. |
| `NonVacuity.CurrentRecoverySwitch` | All fifteen premises and H4's six on a switching network, a reachable initialized world that meets `LiveAt` before any Unzen proof, and H4 applied there (`live_recovers`): the path proves the Unzen lane, latches the authenticated start and lands | `NonVacuity.CurrentRecovery`'s environment with the switching fields set, so that profile's restrictions apply except the new-network ones: `setOrigin` writes S = 5 from a hash-bound legacy header whose timestamp is before `forkTime`, and the path runs `unzenProve`. One legacy header and one valid proof, of the final proposal 1; `unzenParent` returns the empty lane's finalized hash 0, so `UnzenExtension` has no true antecedent in this profile (no hash-bound header has EL hash 0), as in `NonVacuity.CurrentSwitch`; `LiveAt` holds by `LiveRules`' first case, so the path's rules replacement is not exercised. No Unzen implementation runs, and nothing has landed in the reachable world.                                                                                                                                                                 |

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
The accepting, switching, equivocation, import, honest-agreement and both joint H1–H4 contracts
are mandatory audit obligations. Finite ordinary
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

The inventory is **67 partial / 512 deferred clauses**, and **44 narrow partial /
44 supporting / 522 deferred binding rules**, plus 33 deferred assumption/limitation rows.
SWITCH has narrow first-fence/root evidence. Five ANCHORLESS clauses (section 4's root
resolution and checkpoint authorization, section 8's checkpoint cutoff) have narrow partial
evidence; the other 96 and all 47 ACCEPTANCE clauses remain deferred. Margin arithmetic,
EIP-4788 deployment and ring-buffer expiry, SignalService storage migration,
production parsing/crypto/EL/guest/token/Solidity/Comet/store refinement, operational
availability, measured resources and full launch/switch/recovery acceptance remain separate.

`testdata/etna_current_conformance` holds vectors generated by the current executable model
(`lake exe etna-vectors --write <dir>`): registry admission (`RegistryPayments`) and
CometBFT validator-state genesis/commit replay (`ValidatorState`). The contracts PR copies
the registry file; implementation harness adoption is not claimed here.

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
