# L2 staking draft: source and verification disposition

## Version and result boundary

This review targets unmerged [PR22425](https://github.com/taikoxyz/taiko-mono/pull/22425),
head `69e26df443e9b5a0f05127d4179e4833fc95823c`, based on
`3602629758beb653423a23608fd1960810efcfac`. It is a separate draft-design
review, not a new mainnet configuration or runtime qualification. All70 changed
files were downloaded at that head; their Git blob identities were recomputed
against the PR file list and independently read back with zero mismatches.

| Core document | SHA256 |
| --- | --- |
| SPEC.md | `377b1e6329cafd27ce56a926f4eecc8c86f4f29574eea2102b31c36b17322ebd` |
| ACCEPTANCE.md | `49c17839c1468018964af46087b96c8d9a31885849f094c4af9cedd87dec596b` |
| SWITCH.md | `23006868a74aee0bf2793ae6ffd28e76543da9728e84c3a2a771c09fa9b08ae8` |
| ANCHORLESS.md | `37a6a5d1ff46da97d2b7d747d4013a1b25081df6ffbb574ccdd9db4d393fece6` |
| README.md | `f19782f8d0b3936358e27c345155633d87d195bf184ccc1827be93ef5894b7dd` |

Two independent scoped source reviews found no confirmed normal-model blocking
contradiction in the inspected committee, penalty, seat, exit and recovery
interfaces. Their Markdown vectors are source evidence, not executed tests.
Concrete implementation, cryptographic and resource evidence remains separate.

## What moved to L2

`EtnaStaking` holds bridged L2 TAIKO and live bonds/seats. Block H's system call
counts misses, applies their penalties and stores the candidate snapshot before
ordinary transactions. A usable candidate decides H+2; a transaction in X first
changes the snapshot at X+1 and the signers at X+3. There are no epoch selection
checkpoints, pending top-ups, activation delays or `activeCommitteeSnapshot`.

The engine is still stock CometBFT with strict greater-than-two-thirds commits.
L1 still owns the fallback key list and `minTotalStake`; the ZK/TEE guest derives
signer sets from authenticated L2/L1 inputs and verifies required commits. This
is not a claim that a new L2 contract replaces Comet's signature verification.
See SPEC COMP-2-6, STAKE-4.2-4..8, COMM-4.3-1..20 and PROOF-6.2-12..19.

## Reviewed transitions and proof boundaries

| Boundary | Reviewed requirement | Remaining evidence |
| --- | --- | --- |
| Snapshot timing | Penalties in H affect H+2; transactions in X affect X+3. Transactions cannot rewrite H's snapshot. | Real block-start and transaction execution ordering. |
| Miss identity | Traverse the parent signing set; use each key's live mapping in the parent post-state. A released/reused seat does not inherit the departed key's miss. | Actual LastCommit-to-ABCI flags, mapping reads and shared EL/guest vectors. |
| Failed system call | Revert/OOG/no code leaves call-owned state unchanged; block stays valid. A stale full-word snapshot height forces fallback. | Actual EL atomicity, continuation and snapshot storage proofs. |
| Candidate/fallback | Exact set validity and power sum; explicit maximum-uint256 threshold disables even a maximum-total candidate. | Full128 record decoding, reserved bits, curve validation, exact storage proofs and ABI. |
| Origin and later anchors | First two blocks use origin-frozen keys; later decisions use the deciding block's anchor. | Historical fallback-list availability and actual origin/import/guest binding. |
| Whole-set replacement | Diff H+1 against H+2, including deletes/additions/common-key power changes. Recovery drops old pending updates. | Actual128-to-128 stock updates, proposer priority/appHash and restart behavior. |
| Proof origin | p+1 comes from authenticated header(p).next_validators_hash, except origin bootstrap; p+2 from p's post-state and p's anchor; p's set supplies p+1 misses. | Actual three-set witnesses at p=o, p=o+1 and later cuts. |
| Commit boundaries | Always check h; check each interior x when the successor key/power set differs. Power-only changes count; labels and identical sets do not. | Real signatures, canonical set ordering/hashes and both guests. |
| Withdrawal | X+2 is the last candidate duty after exit at X; U+2 plus the evidence window establishes a height relation. | FI/evidence delivery, fastest legal production, recovery/bridge clocks and implementation. |

The proof-origin root exception is narrow: PROOF-6.2-33/47 allows p's already
landed EL header to authenticate p's old anchor for the p+2 decision. It does
not waive the ordinary L1 ancestry check when p+1 inherits that anchor.

Proof and blob coverage remains the full (p,h] even if execution settles only
(c,h]. Atomic c matching and overlapping landings remain governed by 6.1.
Landing at any height was already present in source360; it is not newly credited
to the L2-staking change. The new proof load comes from possible key/power
changes at every height, not from an epoch-only transition count.

## Accepted or open limits, not new defects

- Fallback keys have no stake and each needs its own caught-up validator
  instance. They are a specified governance/availability dependency.
- A LastCommit flag is not independent evidence that its key signed. Stock late
  precommit processing, proposer omission and honest trust/signing refusals can
  produce misses; LIMIT-12-24/-31/-33 already state these effects.
- System processing can use30M EVM gas in the block and again in a FI singleton
  trial, outside the ordinary zk-gas meter. Fallback handles a failed call, not
  an expensive successful call that a guest cannot prove. If c already contains
  that code, recovery inherits it and a repair transaction's block runs the call
  first. LIMIT-12-29 and Q3.2-6 already describe this; it needs real-guest budget
  evidence and an explicit repair policy, not another toy PASS.
- Commit verification may reach128 signatures per block, not per epoch.
- U's target becomes151,200 blocks, with allowed maximum262,144. Seven days uses
  the illustrative4s rate; it is no wall-clock outage/evidence guarantee. Catchup
  requires proving/landing capacity above production and retained L1 ancestry.
- L2 TAIKO integrity, DAO upgrades and unbacked-token bridge loss are explicit
  assumptions/limits. A valid ZK landing cannot establish external token backing.

## Exceptional verifier-repair identity obligation

A non-blocking, unverified repair obligation remains distinct from normal
protocol execution. FORF-4.4-2 authorizes only after landed issuance, so ordinary
recover cannot discard that issuance: the settled prefix stays. The attempted
ordinary-recovery counterexample is therefore rebutted.

After a dual-verifier failure, a bespoke repair can instead void the landing
that supplied the issuance. If it restores an earlier L2 issuance counter and
later reuses that id while a canonical-L1 authorization for the old id remains
executable, a three-argument `forfeit(bondId,incidentId,validUntil)` has no key
parameter that distinguishes the old issuance. STAKE-4.1-13a and FORF-4.4-16
require no id reuse/same-key identity; simply assuming a repair violates those
invariants does not prove a conforming implementation has an exploit.

The concrete repair must establish identity preservation or invalidate/bind
old authorizations atomically. RECOV-8-27a's L1 received-signal/RETRIABLE cache
revocation does not itself specify treatment of canonical L1-to-L2 governance
messages. No actual transport or verifier-repair implementation was exercised;
this is outside the normal verifier-soundness model and is not a confirmed
normal-path or implemented-code defect.

## Historical evidence and concrete follow-up

The existing product bundle2e676, source-only f556/360 ledgers and their models
remain unchanged. The generic runtime/workspace classifier does not admit this
draft. The separate draft model is a symbolic boundary abstraction only.

| Previous evidence | Current disposition |
| --- | --- |
| L1 Registry lifecycle/top-ups/confirmation/slash/forfeit traces | Historical only; L2 seats, immediate updates and L2 delivery must be revalidated. |
| Epoch D/S/H and activeCommitteeSnapshot models | Historical only; not a proof of per-block snapshot/fallback or X+3. |
| Frozen Comet signatures/native store/replay receipts | Retain original pin/scope; no current staking/App/EL/guest integration credit. |
| Existing493 TLC outcomes and760 ordinary checks | Historical regression at supported sources; not blanket conformity to this draft. |
| Unzen Derivation Lean package | Etna remains explicitly excluded; a source pin update adds no Etna proof. |
| Fourteen source360 runtime obligations and19 archived searches | Preserve WAITING/INCONCLUSIVE; this draft table is not an additive completion counter. |

Concrete remaining work includes the actual staking/EL/guest block-start path,
all128 record witnesses, per-block candidate/commit proof-origin vectors,
128-to-128 replacement/restart, L1-to-L2 governance delivery, withdrawal/evidence
service, full-proof cost/backlog and public/private history recovery. The draft
model's selected finite bank will be recorded separately after independent
behavioral verification; it closes none of these absent implementations.

## Executable model and observed checks

The separate [draft model](draft_rules/README.md) uses symbolic validated keys
and pre-authenticated anchors. It does not check LastCommit quorum feasibility:
some arbitrary missing-key probes, including a sole parent signer marked
missing, are helper-state inputs that no valid stock commit could contain.
They establish neither consensus reachability nor actual slashing behavior.
One additional four-member trace uses Q=10^27/4, valid deployment arithmetic,
and three retained unit-power signatures above a strict2/3 threshold. That
numerical example still supplies no real signatures or executed Comet commit.

Initial23 model tests and17 independent checks passed but did not cover a
checkpoint with an empty seat retaining a historical miss counter. Source
review found that the constructor wrongly required such counters to be zero
and exit cleared them. The normative rules explicitly reset on taking a seat
and ignore empty seats during counting; the projection must admit retained
checkpoint counters. Two new regressions produced an actual semantic RED on
the original model, then passed after removing only those restrictions.

The accepted model hash is
`6065102a60535af159ce7ee54cd3a1915a9980783ad4da67082fa7dfe27b5c82`.
At that hash,25 regressions passed normally and with Python optimization;
17 independently frozen checks plus2 supplemental checks passed in both modes.
Four private-copy faults were each detected by a named semantic assertion:
truncating snapshot height, ignoring power-only commit boundaries, using stale
snapshot positions as live seats, and taking the snapshot after transactions.
Each exact byte restoration passed the original17 checks, followed by the
supplemental counter checks. Canonical code was not mutated.

The closing26th quorum-feasible numerical trace also passed normally and under
optimization at the same model hash. Fresh ordinary suites passed786 checks
(600 main,166 conformance,20 sensitivity), with zero failures/errors/skips, in
each supported360/f556 document context. Direct calls to the unchanged runtime
classifier accepted the known context and rejected the actual69 draft bytes;
the product pin and five-bundle inventory stayed unchanged. The complete-diff
source review of the coherent model passed. Existing-draft publication and CI
readbacks are recorded after commit in the PR status prefix and monitor ledger;
no network outcome is predicted by this checked-in source snapshot.

The draft rule corpus ran in an inspected offline copy built from the actual
360 base documentation plus all70 draft changes:630 live markers,101 retired,
assets/links/tables passed. Migration purity was explicitly skipped. An earlier
copy mistakenly used the formal branch's older unchanged documents and produced
a false dead-link report. Correcting the source base resolved it without an
edit to the normative draft. This fixture error is not a protocol finding.

The first whole-cohort attempt had600 main and166 conformance passes but three
sensitivity cleanup errors. Causal probes found that the temporary caller had
omitted the inner `env --default-signal=INT,QUIT,TERM,HUP,PIPE` used by the
established invocation: the child inherited ignored SIGINT/SIGTERM dispositions.
A controlled sleep ignored SIGTERM in that variant; the established invocation
restored defaults and terminated it normally. No cleanup code or timeouts were
changed. Fresh complete cohorts with the corrected invocation passed as above;
the failed logs and diagnostics are retained separately.
