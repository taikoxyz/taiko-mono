# Review corrections

The first three sections record the first correction pass. Its counts (420 contracts,
47 tests, 172 partial / 441 deferred) are historical, and so are the counts of the second,
third and fourth passes. The current numbers are in the last section ("Headline-theorem
restructure") and in the README.

Baseline: PR #22292 at `2f884b06f10fae4e48104ada88cada05b3d80fd5`. These changes
repair formal evidence and its tooling. No production contracts/clients/guests are
changed. Plans and execution logs stay untracked.

## Findings and corrections

1. **Deployment/config binding:** the previous Rules/Context properties were relative
   to supplied decoded inputs. Rules' config hash function alone did not establish
   deployment binding; L/genesis/committee0 were missing from State. State now includes
   initialized L, genesis cutoff and committee-0 commitment, plus an authenticated
   decoded config-preimage projection. That projection is ghost input, not four new
   storage slots. `Deployment.build` checks its supplied config equals the fixed
   projection, checks the opening/committee0 commitment, and constructs Rules using
   these values and fixed hash adapters. A valid alternative unit=9 is rejected even
   under a constant hash adapter. `constructed_configuration_unique` proves two
   successful constructions on the same State cannot choose different configs.
   Real storage authentication/opening and Keccak separation remain explicit external
   premises; the conditional `opening_unique` lemma is supporting evidence only.
   DV-03, HS-03 and HS-06 now state that distinction and name the stronger construction.
2. **Stored evidence key:** slash actions no longer carry a key or an authentication
   Boolean. They carry votes and raw abstract signature bytes/identities. The registry's
   fixed verifier is invoked twice with the current bond.key. Registry traces preserve
   that verifier. Generic success proves both verifications used the stored occupant;
   regressions show old-key signatures valid for key7 fail after slot reuse by key8,
   while key8's signatures succeed. Actual key decoding/sign bytes/ecrecover are external.
3. **Claim/source graph:** the earlier lists produced 194 absent Cartesian pairs and
   included deferred requirements. Each claim now records explicit source→theorem
   pairs; the checker requires an existing reviewed manifest edge, general-property
   role and a partial/proved source. Unsupported node/DAO obligations remain deferred.
   An incorrect claim edge from the Chinese "proposer fetches events" clause is removed:
   the raw-witness text is a separate clause (in both languages), distinct from proposer
   fetching. Finite wrong-hash regressions may link the raw-witness clause; the
   zero/one-cursor claim does not claim fetching.
4. **Kernel integrity and semantic scope:** the supplied skipKernelTC/addDecl attack
   was reproduced: the old audit accepted an ill-typed theorem with no forbidden axiom.
   Audit now replays Etna and the generated Audit olean with leanchecker. The exploit
   is rejected. An ElectionValid=True mutation previously compiled; a separate explicit
   unfolded election contract now makes it fail. The duplicate policy and pinned
   self-comparison are removed. A single reviewed expected-type/evidence manifest
   remains; exact-type checks are not advertised as automatic prose/spec equivalence.
   Simultaneously changing a definition, its semantic contract and its tests still
   requires substantive review; no in-repo checksum can prevent that.

## Repository packaging

- Removed committed superpowers plans, generated Audit/coverage, duplicate policy and
  historical generated validation JSON. Earlier revisions remain in normal git history.
- Committed `generate_artifacts.py`, which reproducibly emits Audit, complete clause
  inventory and source hashes to ignored `.scratch/generated`. Runtime audit results
  are emitted there after checks; canonical inputs contain no second reverse index.
- Public source derivatives preserve normative text while stripping Notion transport,
  internal page URLs and discussion attributes. Edit times and original/public digests
  are retained. Already-pushed old commits still contain raw snapshots; this normal
  update deliberately does not rewrite public history or claim to retract those bytes.
- Content-based clause IDs replace source-line identities. All 619 prior clauses were
  migrated by exact normalized sanitized text, with no fuzzy/line-based relinking.
  Unrelated line insertion preserves IDs; editing a linked clause requires reviewing
  its new evidence edge. Line ranges remain derived locations. No bilingual semantic
  equivalence or full-spec coverage percentage is inferred.
- DAO cancellation is cited to §8 **Verifier failure** (original spec L467), not §8.3.
- Net 174→172 partial was six status changes, not two: the FI "Included" table row
  (EN-a0d7e057533c65e9) and the "at/after due, neither includes nor skips → invalid"
  rule (EN-7fdd2e21c46727ee) became deferred after pruning `Forced.*` edges, and
  "L and L1_0 fixed at init" became partial through `Deployment.build_binds_parameters`;
  each with its ZH twin.
- Scoped `.github/workflows/formal--etna.yml` runs build, generation, exact-type/kernel audit and tests. Checkout is commit-pinned; Lean Linux release bytes are SHA-256 checked against the official release digest.

## Validation (first pass, historical)

Pinned Lean 4.35.0-rc4: build succeeds with zero warnings; audit checks **420** full
contracts with kernel replay and allowed transitive axioms only (`propext`,
`Classical.choice`, `Quot.sound`). **47** Python tests pass, including explicit graph
mutations, definition/kernel attacks, deterministic generation, line-stable identities,
public sanitization, deployment substitution and stored-key evidence traces.

The source inventory has **619** clauses: **172 partial, 441 deferred, 6 design-pending**;
none is fully proved. A theorem count is not coverage. The final independent review and correction pass are recorded below; hosted CI
execution is checked after push.

## Independent review and correction pass

The fresh reviewer checked immutable `2f884b06..be95dd89`, independently passed the
42-test pre-fix suite and the 420-contract audit and verified both sanitized snapshots against baseline.
No model/deployment/slash finding or Minor was reported. Two additional Important
auditor bypasses were reproduced and fixed in one pass:

- A fake clean stdout axiom message preceded the real forbidden-axiom report. The
  auditor now directly checks Lean axiom dependencies instead of trusting stdout,
  additionally rejects duplicate reports, and rejects unconsumed output.
- Source regexes missed indented public proofs backed by a new axiom. Completeness
  now enumerates actual Lean module/declaration-range metadata, excluding only private
  helpers and generated projections from the explicit manifest requirement. All package
  declarations still have direct axiom dependency checks. The formatted/nested proof
  cannot escape the gate by avoiding a textual theorem regex.

Five negative regressions failed against the old auditor and pass after repair:
forged stdout, indented theorem, attributed theorem, nested namespace and omitted
poison-backed public theorem. The complete post-fix suite passes 47/47, the 420-contract audit
passes, and deterministic generation is checked. No second review substitutes for
these regression and full-suite results. That pass did not address seven Minors from
the original review; the second correction pass below does.

Review scope rulings: actual crypto/MPT/signature/EVM inputs remain external (real
instantiation is unproved); full prose-spec/production conformance needs human review;
previous protocol gaps remain unproved. The reviewer could not execute Linux CI, so
the hosted result was checked after push. History rewriting remains excluded,
so old raw URLs/text are still retrievable in earlier commits.

## Remaining boundaries and decisions

The frozen 12:07 Asia/Shanghai edits remain the source authority; newer revisions need
an explicit refresh.
Typed authenticated inputs, real crypto/L1/MPT/KZG/payload/EL and production/EVM
refinement remain external. Full Comet locking/liveness, durable signer/node trust,
origin uniqueness, exact FI contents, DAO cancellation, trusted rollback targets and
irreversible payouts are not newly proved by these corrections. Raw false-verifier
landings remain intentionally representable; the stronger settlement claim separately
requires a valid batch, shared statement and built deployment/history context.

## Second review corrections (baseline `2a5d899ae`)

A re-review of `2a5d899ae` reproduced the remaining gaps below with kernel-checked
witnesses and gate mutations. Every item is fixed with a regression; nothing outside
`formal/etna` and its workflow changes.

**Model**

1. **Committee 0 was unbound.** `Deployment.build` took the hash functions as
   arguments, so under a constant record hash two different genesis committees both
   built on one State, while claims said committee 0 was bound "including under a
   constant hash adapter". The adapters are now ghost World fields that callers cannot
   choose, State holds the authenticated committee-0 opening, and `build` recomputes the
   genesis election and requires it to equal that opening. `constructed_committee_zero_unique`
   and `constructed_rules_fixed` replace the witness; `constant_record_hash_binds_committee_zero`
   rejects it.
2. **Recovery ignored stored deployment values.** `Recovery.Config` carried its own
   L/unit/minimum/nMax; recovery now reads the stored L and configuration
   (`recovery_uses_stored_deployment`, `recovery_reads_stored_deployment`).
3. **Spec immutables came from a free template.** maxAnchorAge and the forced-inclusion
   delay are State immutables. `build` enforces the expressible §10/§11 initialization
   constraints (`build_initialization_constraints`); unfolded `_root_` pins cover `Ready`,
   the constraints and `build`, so deleting `3 ≤ L` from `Ready` now fails the build.
4. **Slash and confirm inputs.** Confirm and slash read the Inbox's initialization
   state; the slash bounty is a registry immutable. `slash_success_double_sign` and its
   converse derive every double-sign condition; HS-01 no longer cites a guard restatement.
5. **Minors from the original review.** Trace-level preservation of every deployment immutable, adapter and
   the registry verifier (including recovery exclusions); trace-level record retention
   (DV-10); snapshot monotonicity along certified traces and across recovery; the
   proof-origin anchor is bound to the authenticated archive (`proof_origin_anchor_fixed`);
   the HS-05 rollback recheck is proved in both directions; regressions now cover K=2
   overlapping landing, FI cursor advance and a generation-1 deployed build.
6. **Evidence.** Twelve pure projections of definitions are `supporting`; DV-02 is
   re-scoped to derived chain properties; DV-01 and DV-04/DV-05 gain derived theorems;
   new claim HS-07 covers deployment constraints and immutables. Three closed facts are
   `constant`, and the unrelated ETNA_COMET_DOMAIN_V1 edge is removed.

**Gate**

- A second Lake library with a `skipKernelTC` constant passed plain `leanchecker Etna`;
  the audit now uses `--fresh`, and the lint pins the lakefile, toolchain and imports.
- Build-time `#eval` could rewrite the auditor; the lint rejects build-time code before
  `lake build`, and CI fails on any tree modification.
- Manifest types were pasted into Lean, so `type_of% @X` matched any statement; types are
  now string literals parsed as one term with forbidden syntax rejected.
- A decoy `Committee.election` inside `Consensus` hijacked the election pin; pins are
  `_root_`-qualified and new enclosing-namespace shadowing must match a reviewed allowlist.
- `tests/*.lean` could hold `sorry` or custom axioms, and manifest modules were unchecked
  for generated declarations; both are now checked.
- Roles were manifest text; they are now checked against kernel types.
- Coverage errors name the clause and theorem; duplicate text on a linked clause fails.
- The sanitizer keeps a placeholder for self-closing internal mentions (one ZH preamble
  line changed). The gitleaks allowlist for the removed ledgers stays, because gitleaks
  scans every commit of the PR and earlier commits still contain them.

**Status changes vs `2a5d899ae`:** 16 EN/ZH pairs became partial: in §10 the deployment
constraints, the "pick a past genesisCutoff" and Inbox-initialization steps, and the
upgrade bullet's "cannot bypass immutability" sentence; in §11 the L1-only parameter
principle and the rows for L/genesisCutoff, vp_unit/s_min/n_max,
forcedInclusionDelay/maxAnchorAge and minStake/delays/slashBountyBps; storage rows
268/269, 272–274, 278/279 and 282; the §4.1 Inbox-address/initialization and
no-membership-proof bullets; and the §3.1 L1-only slashing bullet. Six pairs became deferred because their only
evidence was a projection or an unrelated tag: block size bound, parentBeaconBlockRoot,
back-pressure rule 5, CometBFT height, dual proofs, and the chainDomain block.

**Validation (second pass, historical):** Lean 4.35.0-rc4, zero build warnings, lint clean; audit checks **514**
contracts with fresh kernel replay; **78** Python tests pass. Inventory: **619** clauses,
**192 partial, 421 deferred, 6 design-pending**; none is fully proved.

**Still open (at the end of the second pass; later passes closed most of it):** the Keccak constants in `Recovery.Config`, registration minimum/delays
and the FI threshold are per-call arguments; registry delays, the 48-byte chain id and
"maxAnchorAge above L1 finality" are not modelled; snapshot monotonicity assumes the
recovery snapshot exceeds the previous one and excludes rollback; `NodeValid`,
`Forced.step` and `Committee.election` are not pinned; shadowing analysis skips
Lean-generated names without source positions. Simultaneous edits to a definition, its
pin and its tests still need human review.

## Third review corrections (baseline `2f756d767`)

A third review found no Critical issue and confirmed the earlier model findings fixed.
It reproduced one gate bypass and found that the evidence rules were applied
inconsistently. All findings are addressed below.

**Gate**

- A closed fact wrapped in a dummy binder (`∀ _u : Unit, _u = _u ∧ C`) passed as
  `property` and could back a fabricated `proved` claim. The audit now requires every
  conjunct, disjunct and existential body of a property's conclusion to use an outer
  bound variable and not be trivially true. The check is syntactic; tautologies such as
  `x ≤ x`, an `↔` with one trivial side or Boolean encodings can still pass. One theorem
  (`conflicting_commits_double_sign`) was restated equivalently to name the common key.
- The coverage check now enforces equal EN/ZH clause counts per theorem and per claim,
  and the same theorems per language in each claim.

**Evidence**

- Theorems that only unfold a definition or a `*_success` lemma (unpacking a guard,
  rejecting on a failed guard, evaluating under a guard, framing unchanged fields, or a
  per-step case split of such cases) were relabelled `supporting` by review: 129 relabels
  plus 2 new theorems labelled supporting,
  including every guard restatement the review named. The rule is conservative, so some
  supporting theorems state spec properties that hold by evaluation.
- Edges whose theorem does not establish the clause were removed: Appendix B storage
  rows (no slot model; the `Genesis` predicate assumes initial slot values), the
  upgrade bullet (upgrades are not modelled), the "Due" clause, and further
  wrong-topic edges found in a scan (grid rationale, atomicity, replay/invalidation,
  4096-slot, slot-290 metadata, history retention, cross-step committee selection).
- All 17 claims are kept and rescoped to derived theorems. DV-01 now proves consecutive
  heights; HS-01 adds `Derived.conflicting_commits_slashable`; HS-07 covers every
  moved immutable, the registry constraints and the §10 step 5 genesis invariants.

**Model**

- maxBatchBlocks, the forced-inclusion fee and threshold and protocolFeeRecipient are
  Inbox immutables; minimum stake and the activation/exit/withdrawal delays are
  registry immutables; the recovery Keccak constants are World adapters. Steps read
  them, `trace_preserves_immutables` covers all of them plus the slash bounty, and
  `build` checks the added §10/§11 bounds.
- `Genesis` states the §10 step 5 initial values. From it, every trace keeps the core
  invariants, both constraint sets, Inbox initialization and committee 0's registry
  snapshot, and the slot-284 monotonicity premise across recovery is derived for traces
  whose landings and rollbacks are certified.
- New pins cover `Forced.step`, `NodeValid`, `Committee.election` and its helpers, the
  registry transitions, `recover` and `Genesis`.
- A three-registrant deployed regression elects a two-member committee 0 and checks a
  block whose commit needs both signers.

**Status changes vs `2f756d767`:** 30 EN/ZH pairs became deferred (transcription-only
evidence or removed edges) and 2 became partial (the §10 operating-parameter
paragraph's maxBatchBlocks ≥ K and the §11 Inbox-immutables row).

**Validation (third pass, historical):** Lean 4.35.0-rc4, zero build warnings, lint clean; audit checks **550**
contracts with fresh kernel replay; **83** Python tests pass. Inventory: **619**
clauses, **136 partial, 477 deferred, 6 design-pending**; none is fully proved.

**Still open:** the verifier result and recover's owner check are per-step inputs; the
withdrawalDelay evidence-window bound, a nonzero slashSink, the leaf-calldata gas bound
on maxBatchBlocks, the 48-byte chain id, "maxAnchorAge above L1 finality" and the
token-supply premise are not modelled; slot-284 monotonicity across recovery assumes
certified landings and rollbacks; the slash bridge assumes the registry verifier accepts
consensus-signed votes; the transcription rule is applied by review, not mechanically
(the fourth pass replaced it with a mechanical rule).
Simultaneous edits to a definition, its pin and its tests still need human review.

## Fourth review corrections (baseline `2e24a0d46`)

The fourth review found no Critical issue and no weakened theorem. It found two model
gaps and that the review-applied transcription rule was inconsistent: about 18 of 44
sampled `property` theorems had `supporting` twins with identical proofs.

**Model**

- `Genesis` now also requires committee 0 to be the genesis-cutoff election (target
  epoch 0, cutoff = genesisCutoff, a valid election over the stored config) over a
  registry checkpoint at or before genesisCutoff. Previously a World with a stray
  committee-0 record and no registry history satisfied it, yet could never build rules;
  that World is now a negative regression, and `genesis_builds` shows a `Genesis` World
  builds for every sorted archive covering block 0. The registry's Inbox-address and
  chain-id check (§4.1, §10 step 5) is not modelled; the registry has no such fields.
- The `recover` pin covered only a wrapper; replacing the forced-inclusion clear-range
  guard in `Recovery.Allowed` with `True` passed the gate. Pins now cover `Allowed`,
  `applyRecovery`, `recover`, rollback, landing, the committee schedule, registry
  history, anchor/registry lookups, the World-level transitions, and the step/trace
  inductive relations (by constructor-listing theorems). That mutation now fails the
  build.
- The slash bridge's verifier premise is narrowed to the votes of the two commits; the
  `SoundStep` docstring states its only rollback premise (`snapshot < now`); a
  non-trivial sound trace (recovery, certified landing, second recovery) now exercises
  the derived recovery premise.

**Evidence rule**

- The audit now computes `property` versus `supporting` from the kernel in both
  directions: `property` exactly when the statement passes Rule P and the proof uses
  induction on a recursive type or another derived Etna theorem. 66 entries moved to
  `supporting` and 19 to `property`; every identical-proof twin the review found now has
  the same role. A new `Derived.chain_switch_witnesses_activate` lifts the switch-witness
  rule along a valid chain by induction.
- The rule is a mechanical proxy, with known effects in both directions: per-step case
  splits and `simp` evaluations that cite an induction lemma count as derived, while
  substantive results proved without induction (the H+2 activation, `genesis_builds`)
  do not.
- Claims: DV-03 (per-height schedule arithmetic, none of it derived) is removed;
  DV-05 cites the new chain lemma; DV-10, HS-05 and HS-07 drop edges whose theorems are
  no longer property, with descriptions adjusted. HS-01 now says which trace each
  invariant holds on.

**Docs:** the README no longer calls transcription "uniform" or counts a "lower bound",
describes the mechanical rule and its limits, corrects the slot-284 recovery wording,
and lists the pins precisely.

**Status changes vs `2e24a0d46`:** 19 EN/ZH pairs became deferred as roles moved to the
mechanical rule, and none became partial. (A slot 283/284 storage-row edge on
`sound_trace_is_trace`, which became property, was removed: there is no slot model.)

**Validation (fourth pass, historical):** Lean 4.35.0-rc4, zero build warnings, lint clean;
audit checks **576** contracts with fresh kernel replay and mechanical roles; **86** Python
tests pass (89 after the follow-up below).
Inventory: **619** clauses, **98 partial, 515 deferred, 6 design-pending**; none is fully
proved. 16 claims.

**Still open:** the verifier result and recover's owner check are per-step inputs; the
registry's Inbox-address and chain-id check, the withdrawalDelay evidence-window bound,
a nonzero slashSink, the leaf-calldata gas bound on maxBatchBlocks, the 48-byte chain
id, "maxAnchorAge above L1 finality" and the token-supply premise are not modelled; the
slash bridge assumes the registry verifier accepts the commits' consensus-signed votes;
the role rule is a proxy as described above. Simultaneous edits to a definition, its
pin and its tests still need human review.

**Light-review follow-up.** A light review confirmed the `Genesis` change and the deep
pins (weakening `Recovery.Allowed` fails the build), and the counts. It found the role
rule could be gamed: one dead `have` mentioning any induction lemma (a private helper,
an inline `Nat.rec` term, or an existing derived theorem) made a non-derived theorem
pass as `property`. The audit now drops bindings a proof never uses before looking for
induction, and records every property's derivation chain in
`.scratch/generated/derivation-chains.json`. No current entry's role changed; tests
cover five dead-binding shapes. A trivial live use of an unrelated induction lemma still
counts; the recorded chains are for review. README wording on the slash bridge's
verifier premise and on which roles are recomputed was corrected. Validation (historical):
audit 576 contracts, 89 Python tests, 98 partial / 515 deferred / 6 design-pending.

## Headline-theorem restructure (baseline `d2606679e`)

The passes above measured the package by clause statuses and theorem roles. This pass changes
what it claims: three headline theorems, fund safety (H1), accountable finality (H2) and
forced-inclusion integrity (H3), each proved under one premise record. The clause inventory,
roles and the 16 narrow claims stay as a traceability report that CI keeps consistent; they
are not the verification result. Nothing outside `formal/etna`, its workflow
(`.github/workflows/formal--etna.yml`) and `testdata/etna_conformance/` changes; the harnesses
that run the vectors live in the Etna contracts PR (#22286) and the Etna client PR (#22280).

**Libraries.** The single `Etna` library is split into `EtnaModel` (definitions, no theorems),
`EtnaStatements` (the premise record and the claims, no proofs), `EtnaProofs` (every theorem;
the headline proofs in `EtnaProofs/Headline/`, namespace `Etna.Proofs`), `EtnaWitnesses`
(regressions, the non-vacuity witness and counterexamples) and `EtnaVectors` (the
conformance-vector generator, which reads only the model). Imports only point down.
`check_imports.py` enforces this before Lean runs, and the audit re-checks the built
declarations.

**Statements.** `Environment` fixes, once per deployment, everything the L1 contracts do not:
the guest relations, the EL header hash, block 0's header and the landings landers submit. So
a premise and a claim talk about the same relations. `Premises w0 env` has seven fields:
genesis, verifier soundness, authenticated FI inputs, config-hash separation, header hashes,
header separation and signature agreement. The claims that need the verifier range over runs
whose landings the environment submits, because a verifier premise over every trace cannot
hold. Two findings shaped the record: a `trustedRollback` premise was considered and dropped,
since no headline proof uses it (what it would protect is in the README), and
`Deployment.opening_unique` is vacuous (`natWord` wraps at 2^256), so config-hash separation
is stated over uint256 openings only.

**Proofs.** H1 follows from a chain-of-custody invariant along runs: every retained landing
record carries the header of its block, joined to its parent's by blocks valid under its
generation's built rules, back to block 0. H2 lifts the per-context accountability and
slashing results to the rules built on every reachable World. H3 has three parts: queue
entries survive every step except recovery blanking, only landings advance the FI head, and
each landing's blocks consume [head, new head) through inclusions or legal skips with real
witnesses. `Etna.Proofs.claims` is their conjunction. Every premise field is read by some
headline proof. Runs differ from traces only in which landings the environment submits: every
run is a trace (`run_trace`), and `Run`'s side condition on other steps excludes nothing
(`trace_run`, stated for an environment that submits every landing `land` accepts on a
reachable World; no environment satisfying the verifier premise does, so it does not extend
the run-based claims to every trace).

**Witnesses.** One deployment and environment satisfy every premise with non-trivial
relations, along a run that enqueues an FI entry, lands twice (consuming it), recovers and
lands again; two more witnesses exercise H2's finality hypothesis, one with a Byzantine
minority. A concrete H1 run covers landings, recovery and rollback. Five counterexamples
document scope, not failures: a run without verifier soundness, an untrusted rollback
snapshot that frees the committee's stake, late stake capturing a recovery committee, a
blanked poison FI entry resubmitted, and a voided DAO authorization revived by a rollback. The
README gives each in plain words with a suggested spec fix.

**Conformance.** `lake exe etna-vectors` writes `testdata/etna_conformance/`, which records
only the model's decisions; each implementation keeps a stamped copy and its own list of known
divergences next to its harness. 334 Inbox and registry vectors run against the Etna contracts
in a Foundry harness in the Etna contracts PR (#22286): 6 known divergences, none a contract
bug. Two are reachable: the free-slot reuse order, which the spec leaves open, and a withdrawal
to address 0, which the contract refuses and the model accepts; the other four need an L1 block
at 2^48 − 1 or a timestamp at 2^48. 340 client-rule vectors run against the Rust client in the
Etna client PR (#22280): all agree except one known divergence, L2 height 2^48, which the model
rejects and section 3.4 does not bound.

**Gate.** The audit now checks that `Etna.Proofs.claims` and the three headline theorems have
exactly their claim types and only the standard axioms, that every premise field is read by a
headline proof, the library contents at kernel level, that statement definitions are unfolded
for Rule P and the `constant` role only when EtnaStatements declares them, and that the
committed vectors are fresh (`check_vectors.py`). The README lists each check's limits.

**Docs and small fixes.** The README is rewritten around the theorems, the premises and what
they leave out. Premise and claim docstrings cite exact spec lines (block 0's Comet hash,
spec L740 and L273; the EL header fields, spec L72-L76 and L341) and state the FI anchor window as
the Lean does; `VerifierSound` gives its equivalent form ("every submitted landing that lands
is certified"); H2's scope and H3's coverage limits are stated plainly. In the manifest, H3
now also cites 8 step 3 (spec L461), which it states, and `build_binds_parameters` names
`Premises.hashSeparation` instead of the vacuous `opening_unique`.

**Status changes vs `d2606679e`:** 8 EN/ZH pairs became partial, all through headline
theorems: §1 "Finality" (H2); §1 "Funds" and the 6.2 withdrawals clause (H1); §1 "Censorship
resistance", 7.2's "neither includes nor skips → invalid" rule, 7.2 "Blanked entries", the 7.3
due queue-head rule and 8 step 3 (H3). None became deferred.

**Validation:** Lean 4.35.0-rc4, zero build warnings, lint clean; audit checks **615**
contracts (93 property, 3 constant, 302 supporting, 217 regression) with fresh kernel replay,
mechanical roles and the headline checks; **143** Python tests pass. Inventory: **619**
clauses, **114 partial, 499 deferred, 6 design-pending**; none is fully proved. 16 claims.

**Still open:** liveness, cross-round safety, checkpoint permanence, the bridge, what happens
after verifier failure, a wall-clock FI deadline and real cryptography stay outside the
claims (README, "What is not covered"). The harnesses and their copies of the vectors are in
the Etna contracts and client PRs, not yet merged; their copies are refreshed by hand from a
pushed formal commit.

## Spec source: the in-repo spec, revision 2026-10-28 (baseline `31bb5d18c`)

**Source.** The package now models `packages/protocol/docs/etna-pos-zk/sources/spec.md` at
revision 2026-10-28. Before, it modelled its own public copies of the 2026-10-27 04:07Z
English and Chinese text. `spec-coverage.json` pins the path, the revision and the file's
SHA-256, and the coverage check compares them with `sources/manifest.json`. Any edit to the
spec therefore fails the check until the links are reviewed against the new text. The spec is
English only. The Chinese clauses, the EN/ZH symmetry checks, the copies and their sanitizer
are gone. Clause IDs keep the `EN-` prefix and are unchanged wherever the text is unchanged.
Spec lines are written `spec L<n>` and renumbered to the new file.

**Changed clauses with links.** The text of 16 linked clauses changed. Ten changed only in
wording and keep their links. Those edits are:

- links to the acceptance checklist;
- "must"/"should";
- "per block";
- the `verifyProof` age argument;
- the wording of slot-285 retention;
- how the block-size rule counts transactions.

Six changed in meaning:

- Blob budget (spec L118). The bound is now zlib's default-settings `deflateBound`, not a
  stored-zlib fallback. As `0x06 ‖ zlib`, one maximum-size block takes at most 124,055 bytes and
  six take at most 744,244, within six blobs (780,264).
  - `Budget` now models `deflateBound` and the 4-byte list header.
  - `cap_derivation`, `single_block_one_blob`, `blocks_fit_blobs` and
    `grid_segment_fits_one_landing` are restated on it, and `stored_monotone` becomes
    `deflate_bound_monotone`.
  - `stored_fallback_fits` is removed, since the single-block theorem now includes the prefix.
- Set key (spec L169). The spec now defines it as keccak256 of the L2 chain id and the
  compressed key, fixed per key. The model's `Entry.key` already stands for a fixed per-key
  value, so the election links stay.
- §8.4 (spec L490-L495). The metadata, genesis and handover bullets are rewritten as "Fixed
  origin record", "Unique genesis" and "First block", with the same rules, and their links move
  to them.
- The old "History retention" bullet is gone, and its links are resolved as follows:
  - Its slot-285 part is now the slot-285 row (spec L740, "never pruned"), which takes the
    settlement-record links, including claim DV-10.
  - Its origin part is the fixed origin record (spec L492), which takes the origin-archive
    links, including claim HS-05.
  - Twelve links that touched it only loosely are dropped. They covered anchor-archive prefix
    arithmetic, L1 clock monotonicity, old registry snapshots, checkpoint monotonicity and one
    forced-inclusion regression. Each of those theorems keeps its other clauses.

**Docs.** Three docstrings that quoted the Chinese text now quote the English lines.

**Status changes vs `31bb5d18c`** (its English half, 308 clauses): the "History retention"
bullet, which was partial, is deleted, so partial goes from 57 to 56. No other clause changed
status.

**Validation:** Lean 4.35.0-rc4, build clean, lint clean. The audit checks **614** contracts
(93 property, 3 constant, 301 supporting, 217 regression) with a fresh kernel replay,
mechanical roles and the headline checks; every premise field is still read by a headline
proof, and **140** Python tests pass. Inventory: **308** clauses, **56 partial, 249 deferred,
3 design-pending**; none is fully proved. 16 claims. The conformance vectors decide the same
cases as before; only their `spec` line citations changed.

## 2026-10-29: align with SPEC/ACCEPTANCE at 39ebefbf33a2702b750e0fb0db7d2a40ff8e8480

- Merge the latest #22303 base and replace removed source/manifest paths with separately
  pinned SPEC.md and ACCEPTANCE.md bytes. Review 118 linked clause correspondences, including
  11 semantic changes; the complete mapping is in source-alignment.md. Inventory schema 4
  includes both authorities and fails closed on an unreviewed edit to either.
- Add pending top-ups, explicit delayed activation, checkpoint-history preservation,
  remaining-principal withdrawal and double-sign slashing. H2 now quantifies over positive
  remaining balance, including pending principal, and proves that entire balance slashable.
- Add fixed-rate ceiling DAO forfeiture with effective-first deduction, independent expiry,
  forced exit, preserved confirmation clock and a lifetime entryKey flag. No forfeiture
  nonce, cancellation or added delay is introduced. Ownership, attribution, token effects
  and EVM journaling remain the stated decoded boundaries.
- Add recovery nonce/deadline/init checks, owner invalidation, and current-nonce increments
  on recovery and verifier rollback, with uint256 overflow rejection. Extend whole-machine
  traces and H1-H3 to include invalidation and the new registry actions. Checked rollback
  wraps a named success-state transformer, as recover already wraps applyRecovery.
- Replace the stale-authorization revival counterexample with concrete rejection and general
  future-trace non-revival proofs. Preserve four independent scope counterexamples; recovery
  committee capture now explicitly assumes no timely nonce invalidation by the DAO.
- Verify the checklist's independent capital-floor and integer blocking-power arithmetic and
  strict concentration bounds under supplied selected-committee/valuation/control evidence.
  Economic shortfalls are never machine guards.
- Register 718 exact theorem contracts (101 property, 3 constant, 358 supporting, 256
  regression), 18 scoped traceability claims and 311 source clauses (62 partial, 246
  deferred, 3 design-pending). Roles are checked mechanically against live types/proofs.
- Generate schema-2 Inbox vectors with 414 cases and retain 340 client-rule cases. New
  schema2 production harness conformance is pending; earlier 334-contract/340-client results
  remain historical at c9708e761. Add independent numerical/ordering vector assertions.

Earlier sections describe their original revisions and retain historical counts/citations.

## 2026-10-29: whole-trajectory principal and signing/exit assurance

- Add an independently computed TAIKO receipt observer with exact projection/lifting for
  every original protocol transition, plus genuine zero-flow failed-call stutters. Derive
  whole-trace principal conservation from slot initialization, including all effective and
  pending funds, payouts, slashing, forfeiture, recovery, rollback and slot reuse. Prove the
  initialization invariant from empty lifecycle states and distinguish a malformed raw-state
  counterexample from reachable behavior. Keep actual ERC20 settlement external and ETH fees
  separate.
- Derive confirmation clocks, full withdrawal windows, lifetime key uniqueness and exact
  effective-exit historical exclusion through arbitrary later original traces. Derive
  identity/history premises from configured zero-slot states; state snapshot coverage and
  the selected signing-cutoff bridge explicitly. Prove permanent generation retirement.
- Add an initialized ordinary-rotation/valid-chain accounting witness, an ordinary historical
  validity-after-withdrawal witness, and a still-current fixed-power-after-full-slash witness.
  Continuous positive collateral backing is a design limit; authentic fresh signing-prefix
  linkage and real signing events remain model boundaries. No fresh-signing withdrawal
  exploit or evidence-delivery guarantee is claimed.
- Register 851 exact theorem contracts (142 property, 3 constant, 403 supporting, 303
  regression), 21 scoped claims and 311 source clauses (71 partial, 237 deferred,
  3 design-pending). Generic sum and observer-correspondence helpers back no source clauses.
- Central clean build and strict audit pass, including standard axioms only, fresh kernel
  replay, nine silent Lean regression modules, all 164 Python tests, unchanged seven-field premise use, vector
  freshness and deterministic source/artifact checks. Independent semantic review found no
  Critical/Important findings. See trajectory-assurance.md and signing-escrow-analysis.md for
  statements, counterexamples, initialization and external-effect boundaries.

## 2026-10-29: actual signer and authenticated prefix connection

- Add a typed prefix, full checkpoint hash/cursor matching, snapshot provenance and actual
  Signer.sign observation with exact message, immutable key and signature-adapter binding.
  Derive request cutoff ordering from the accepted source and real replay inclusion, rather
  than assuming the desired cutoff inequality. Cover fresh durable-log writes separately
  from cached retries and preserve covered cutoffs under future archive append.
- Instantiate the composed theorem from a genuine initialized deployment through ordinary
  rotation, confirmation and withdrawal. Add a full typed stale-view fresh nil-signature
  witness with an authoritative HRS log; both newer checkpoint inclusion and causal
  confirmation-to-view ordering are unavailable. Distinguish this from an extension above
  the latest global checkpoint and report exact freshness, adapter and rollback conditions.
- Register 894 exact contracts (154 property, 3 constant, 410 supporting, 327 regression),
  preserving all prior 851 contracts. Traceability: 311 clauses, 73 partial, 235 deferred,
  3 design-pending, 22 narrow claims. Add seven negative kernel binding mutations plus a
  silent baseline; all 172 Python tests and 12 Lean regression modules passed.
- Independent semantic review found no Critical/Important findings. Full central gate results
  are recorded in README; no production/spec changes or superpowers planning documents.
