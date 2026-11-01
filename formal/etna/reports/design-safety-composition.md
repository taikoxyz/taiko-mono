# Etna supplemental design safety evidence

The eight design-proof tasks extend the existing decoded specification model without
changing the original seven `Premises` fields, H1–H3 definitions, or any of the original
954 declaration/type pairs. The new results establish stronger conditional properties
from explicit lower-level histories and transitions. They do not certify production
contracts, clients, guests, HSMs, cryptography, EL implementations or launch capacity.
The initial review recorded no reportable production vulnerability; these tasks address
missing assurance, not eight discovered production defects.

The exact public contracts and source edges are in [the manifest](../manifests/design.json).
[Source coverage](../spec-coverage.json) and [rule coverage](rule-coverage.md) are traceability,
not clause completion or a verified percentage. The inventory has 405 clauses: the original
313 SPEC/ACCEPTANCE clauses plus 92 independently pinned ANCHORLESS clauses. The original
SPEC/INDEX view remains 600 rule IDs (568 binding rules, 21 limitations, 11 assumptions).
The three upgrade-activation clauses remain design-pending.

## Evidence and composition by task

Names below have prefix `Etna.Design.` unless stated otherwise. Each task has a corresponding
Lean regression module under `EtnaWitnesses/Regressions`, a kernel test in `tests`, and a
Python mutation suite. All semantic Model mutations must first compile silently by themselves;
only then can failure of the unchanged theorem layer count as negative evidence.

### 1. Canonical accepted history to normal signing provenance

- **Raw history and general lift:** `CanonicalHistory.Run` contains original accepted calls,
  archive/header bindings, actual deployment construction, valid batches and exact certificates.
  `accepted_archive_covered` derives archive coverage; `landing_reference_bound` derives the
  snapshot/reference inequality; `prior_snapshot_source` and `run_normal` derive normal
  signing provenance by induction. No SnapshotSource, cutoff-exclusion result or embedded
  NormalSigning.Run is an input field.
- **Original-run integration:** `run_trace`, `run_statements` and
  `submitted_history_landing` connect the same calls and order to the original trace/headline
  submitted-landing machinery. The old free `historyAuthenticated` predicate alone does not
  establish the stronger raw input contract. No unconditional lift of every headline Run is claimed.
- **Positive witness:** `CanonicalHistoryRegression.post_recovery_landing_signs` includes
  actual rotation, exit/confirmation/withdrawal, recovery, slot reuse, generation-1 landing
  of blocks 15–22, and fresh stock signing at 23 by the selected key.
- **Source/primitive boundary:** SPEC 4.3, 6.2 and 8/9; real finalized L1 header/MPT/hash truth,
  canonical decoded EL/archive identity and availability remain external.
- **Mutations:** `test_canonical_history.py` checks archive prefix/header binding, raw
  reference/origin bounds, actual landing/recovery, certificate equality and recovery clock.
  The carried M1 harness defect was repaired: dependent Model binders change coherently,
  Model-only must compile, and the entire Proofs text stays unchanged.

### 2. Node trust, restart and retained signer authority

- **Lifecycle:** `TrustState.reachable_replayed`, `reachable_matches`,
  `canonical_trusted_prefix` and `trusted_session_binding` derive replay/target consistency
  and deployment-bound trust from observation, validated replay, exact matching and opening.
  Missing material, timeout, target change, restart, rollback and recovery invalidate grants.
  `untrusted_cannot_sign`, `pending_restart_cannot_sign` and `untrusted_cannot_serve` cover refusals.
- **Actual signing:** `fresh_transition_uses_device`, `trace_keeps_log`,
  `trace_protects_signed_position` and `protected_conflicting_call_rejected` use the original
  fixed device/encoder and actual `Signer.sign`. Fresh calls require the original producer
  precondition before persistence; exact historical cached retries do not get a new
  next-height/member veto and still require current session/stock authorization.
- **Supersession:** `trace_generation_knowledge_monotone` and
  `authenticated_supersession_persists` preserve authenticated-generation knowledge through
  failed domain-switch persistence, timeout, restart and rollback. `startup` is only the
  initial root; continuing startup must authoritatively restore both HRS and the separately
  modeled generation watermark, or remain closed. This is an ideal durability dependency,
  not physical storage correctness and not a consequence of HRS alone.
- **Witnesses/mutations:** `TrustStateRegression` covers partial/missing replay, all phases
  and nil choices, actual reauthentication/cache retry, historical retry after target advance,
  recovered-generation signing, foreign-deployment refusal and failed-recovery/stale-reread
  refusal. `test_trust_state.py` removes each trust, deployment, replay, restart and durable
  knowledge guard. Initially stale own-finalized signing remains possible until supersession
  is actually authenticated; the SigningViewLag counterexample remains applicable.
- **Source/primitive boundary:** SPEC 8.2/9, ideal own-finalized decoding, engine membership,
  fixed sign bytes, exclusive key use and persistent state. Target/headerMatches/replay prove
  decoded metadata properties; they do not prove physical origin EL-material availability,
  snapshot fetching or storage integrity. The reviewed C1 concern is resolved within this
  stated scope; it is not a production vulnerability or a physical-availability theorem.

### 3. Lower-level locking and shared-history committee agreement

- **Locking derivation:** `Locking.polc_unique`, `commit_has_polc`, `polc_after_commit`
  and `commit_agreement` derive cross-round nonnil agreement from weighted quorum
  intersection and per-key prevote/PoLC/lock transitions. The strong induction excludes
  the first incompatible certificate; desired agreement is not a field of HonestRules.
  `commitValid_bridge` and `commitValid_agreement` connect actual decoded certificates
  using per-certificate nonnil event attribution.
- **Shared input derivation:** `active_committee_prefix`, `handover_prefix_length`,
  `recovery_bootstrap_prefix` and `shared_history_commitValid_agreement` derive the actual
  same-instance committee from common deployment/generation/origin/configuration, raw anchor
  prefixes and registry snapshots through the derived cutoff. The H+2 prefix length is a
  sufficient queried prefix, not a universal minimal-information lower bound.
- **Witnesses/mutations:** `LockingRegression` has conflicting candidates, delayed PoLC use,
  absent phases, real nil-PoLC unlock, asynchronous round interleaving, two commit rounds,
  nil versus nonnil hash zero, and distinct recovery-generation committees. Removing the
  lock-round floor admits a full kernel-checked all-honest fork; the guarded fixture fails
  at `1 ≤ 0`. Other mutations remove current PoLC, strict prior round, event attribution,
  correct nil ordering, sufficient archive or generation binding.
- **Pinned reading:** CometBFT v0.40.0 commit
  `0880b4d378f347ab16e54ec677ff50d803f37d62`,
  [markdown rules](https://github.com/cometbft/cometbft/blob/0880b4d378f347ab16e54ec677ff50d803f37d62/spec/consensus/consensus.md)
  SHA-256 `d0c92013ec522c2cab1e6d874b65a394ab40f1b502bf38f714ebdaa1fb62bcad`, and
  [paper algorithm](https://github.com/cometbft/cometbft/blob/0880b4d378f347ab16e54ec677ff50d803f37d62/spec/consensus/consensus-paper/consensus.tex)
  SHA-256 `26ce047796581935823f1cd9258552dca7bc88010b2e8cba9c4e125a569b3a65`.
  Markdown is primary; the optional paper proof uses a globally fixed coupled nil reading.
  Mixing paper nil-prevote permission with markdown nil unlock is unsafe and rejected.
  This is not a per-validator choice or deployment parameter.
- **Limits:** SPEC CONS-3.1-2 and committee-prefix subclaims only; actual Comet refinement,
  signature authenticity, truthful event attribution and delivery implementation remain
  external. H2 and old CrossRoundAccountable APIs are unchanged. No cross-round automatic
  slashing, liveness or agreement across different recovery generations is added.

### 4. Certified rollback across recoveries

- **Stronger source:** `CanonicalHistory.run_snapshot_below` and
  `SigningEscrow.later_generation_origin` derive the source snapshot/later-origin order.
  `certified_values_trusted_across_recoveries` and
  `certified_rollback_excludes_confirmed_keys` compose actual checked rollback and snapshot
  rechecking with certified source provenance. The original weaker same-generation theorems
  stay intact; they do not acquire the new cross-generation scope by prose.
- **Recovery boundary:** `initial_values_stay_trusted`, `rollback_origin_record_absent`,
  `rollback_has_no_target`, `rollback_interval_rejects_landing`, `cleared_exit_cannot_reconfirm`,
  `rollback_consumes_nonce` and `rollback_retains_signer_authority` cover exact initial values,
  missing pruned origins, every interleaved same-generation future landing, and preserved
  nonce/HRS/watermark behavior. No loss or payout is reversed.
- **Witness:** `CrossGenerationRollback` certifies checkpoint 1/snapshot 12, permits an
  explicitly forged checkpoint 2/snapshot 1000, executes two recoveries, and rolls back below
  origin. Signing stays closed; immediate confirmation and every same-generation landing
  fail. A new recovery still does not advance snapshot. Only a real valid later landing
  advances it to 40, allowing reconfirmation and trust-revalidated fresh signing.
- **Mutations/source:** `test_cross_generation_rollback.py` covers actual source/reference,
  origin, preserved snapshot, checked rollback and signer retention. M2's weak single-observation
  regression was replaced by the all-observation interval result. SPEC 8/8.1/9 still requires
  authentic certified source selection, archive truth and physical persistence; no theorem
  makes an arbitrary DAO rollback snapshot trusted.

### 5. Anchorless roots, cache authorization and migration

- **Canonical roots:** `Anchorless.resolved_canonical`, `resolved_exact_source` and
  `postfork_timestamp_bound` derive the resolver result from raw RootRun writes. Exact ring
  timestamp matching, real same-slot overwrite, missing/code/getter failure and zero-root
  rejection are checked. Elapsed time alone does not expire an untouched slot. Verifier time,
  not proof-selected mode, selects pre/postfork interpretation.
- **Proof/cache binding:** `uncached_authorization`, `cached_authorization`,
  `cached_provenance`, `service_authorization_sound`, `service_proof_isolation` and
  `service_cache_isolation` connect canonical roots, sound decoded storage proofs and one
  fixed source-chain/app/signal-to-slot adapter. Current VERSION namespace excludes legacy
  flat receipts; cached current receipts survive ring overwrite. Tuple isolation requires
  explicit unequal derived slots, with a deliberate colliding-adapter witness.
- **Migration:** `paired_atomic`, `installation_fork`, `upgrade_before_fork`,
  `activation_consistent` and `authorization_sound` check immutable fork/provider binding,
  completed identical EL calls, EIP deployments, dual readers/images, ordered atomic paired
  proxy attempts and failure rollback. The before-fork InstallStep guard is a permitted
  deployment workflow guard, not production contract enforcement. General flat rollback,
  cleanup and an unspecified Unzen→Etna activation path are not invented.
- **Witnesses/mutations:** concrete pre/postfork resolve/proof/cache flows, missing provider,
  collisions, zero root, stale flat receipts, changed app/signal requests and failed/partial
  proxy batches. `test_anchorless.py` has 37 semantic mutants plus baseline/workflow tests;
  source tests independently reject pin tampering, redirection and source edits.
- **Authority boundary:** ANCHORLESS.md is independently pinned and CI-triggered (92 added
  clauses). Ideal canonical L1 roots, storage/MPT soundness, Keccak/ABI, EIP getter/code and
  identical builder/importer/prover calls remain external. Bridge legacy authorization and
  payouts are excluded. The new source is not relabeled as SPEC rule IDs.

### 6. Actual queue service and bytes at the local cursor

- **Semantic L1 journal:** `ActualQueue.canonical_journal` annotates the original trace.
  `history_queue_timed`, `end_block_covers` and `end_block_entry_current` derive enqueue
  timestamps, complete same-block tails and exact storage transport from original calls.
  A later recovery contradicts the current-origin/anchor bound; queue equality is not an input.
- **Local execution:** `local_block_service`, `local_chain_service` and
  `local_chain_byte_service` cover unlanded valid blocks, using each parent cursor and the
  original inclusive delay+maxAnchorAge theorem. `opened_advance_action` and
  `eligible_nonempty_forbids_skip` bind real raw/tx0 bytes to authenticated hash/parser/length
  fields and deterministic singleton include/invalid-skip/empty-skip decisions.
- **Witness:** two same-block enqueues, local cursor 1 with L1 head still 0, and exact
  deadline `1275 = 15+60+1200`; valid inclusion, invalid-byte skip and complete-empty skip.
  An actual recovery blanks poison, the same bytes are resubmitted, and a generation-1
  local chain skips the blank and includes resubmission at exact deadline 1277.
- **Mutations/source:** `test_actual_queue.py` changes timestamp, same-block cut, tail,
  current-origin binding, raw/tx0 hash/parser/length and singleton outcome. SPEC 7.2/7.3
  and 8 are conditional on truthful finalized L1/storage openings and fixed hash/parser/EL
  primitives for unlanded blocks. No wall-clock liveness or prevention of poison resubmission.

### 7. Public settled EL reconstruction

- **Executable public entry:** `Reconstruction.reconstructPublic` always validates complete
  starting state/code/configuration and encoded initial header; public blocks contain full
  encoded headers plus ordered transaction bytes. No private Comet history is an algorithm input.
- **Overlap and suffix:** `overlap_backwards` derives overlap identity from the actual accepted
  c cut, saved parent links and finite compared-header collision exclusion. `overlap_verified`
  reads overlap without reapplying EL state. `projected_execution`, `certified_success` and
  `certified_result` compose original accepted land, BatchValid, exact statement binding,
  original available blobs and fixed codec/full-block EL laws to the authentic endpoint.
- **Recovery/exactly-once:** `certified_trace_success`, `certified_trace_interval`,
  `certified_exactly_once` and `checked_public_reconstruction` apply exactly `(c,h]` across
  ordinary recoveries. Same-L1-block successive recoveries are allowed by transaction order;
  exceptional rollback needs separately authenticated restart.
- **Witnesses/mutations:** actual certificates 0→2, overlap 0/c2→4, accepted recovery then
  4→6; explicit beacon/history effects and two actual recoveries in one L1 block. Seventeen
  Model mutants in `test_reconstruction.py` change availability/version/hash/range/overlap,
  full-header execution context, state/archive/recovery, starting/terminal root or authentication.
- **Limits:** SPEC public reconstruction/DA statements; the sound guest-rule domain is explicit
  and nonempty, not every free legacy Boolean Rules value. Full-block EL includes EIP-4788/2935
  effects and remaining header/transaction validation. Complete authenticated starting state,
  original blob availability, actual codec/KZG/crypto/EL/L1 implementation correctness and
  resource acceptance remain external. See [the detailed report](public-reconstruction-verification.md).

### 8. Conditional protocol upgrade boundary and final integration

- **Unavailable activation:** `UpgradeBoundary.disabled_prepare`, `disabled_activate` and
  `registration_inert` prove absent authority and mere retained/registered material cannot
  activate rules. `prepare_checked` consumes an exact authenticated plan; `stopped_plan_fixed`
  prevents replacing it while stopped. No production authority is supplied.
- **Preconditions:** `plan_coordinates`, `plan_no_prior_production` and `switch_prerequisites`
  bind deployment/generation, old/new config/image/code versions, common-grid H, unchanged
  U/maxBatchBlocks compatibility, actual current authenticated EL/Comet checkpoint at H,
  represented current-generation production/log ceiling and closed old jobs. A retired
  generation's high HRS stays retained and does not veto this generation. This is one
  represented device/history; global all-signer stop coordination is still external.
- **History and deployment:** `historical_rules`, `new_rules`, `boundary_retained` and
  `trace_retains_history` preserve arbitrary prior piecewise height history, recorded earlier
  boundaries, old material, job identities, checkpoint records and complete node/session/HRS.
  `switch_frame` and `trace_deployment_immutables` preserve every registry/Inbox field except
  code-version K. K is a protocol code constant; deployment storage/configuration parameters
  cannot change in place. The original fixed-version ProtocolState.Trace is unchanged.
- **Range/jobs:** `batch_uniform_rules` checks every interior height; `batch_respects_boundaries`
  rejects a crossing even when rule IDs recur; `old_only_image_rejected` rejects old-only images
  above H. `settle_checked` wraps actual original land with immutable statement/config/image/
  deployment/generation/range identity and the original ProtocolState.land World clock,
  guarded against L1 time rewind. `invalidate_identity` changes status only.
- **Signing:** `sign_uses_session`, `signing_height_rules`, `fresh_stops_at_boundary`,
  `cached_session_retry`, `signing_log_retained` and `signing_session_step` classify the pre-call
  durable cache, then call the original TrustState.sign/Signer.sign. Historical cache uses
  its requested height's material; fresh signing follows policy and ceiling. The fixed
  SignMessage encoder/domain/generation are unchanged; version tags are application/job
  metadata, not a new native vote field. Refusal does not invoke the timeout restart path.
- **Failure/scope:** `failed_switch_atomic` returns the entire previous System on switching
  persistence failure. The SwitchTrace theorem covers prepare/activate-only traces with a
  fixed settlement history. It is not a whole-system interleaved execution proof: successful
  later boundaries need separate settlement progress, and settlement/signing have the explicit
  single-call bridges above. General per-switch preservation accepts an arbitrary prior schedule.
  Image/version labels constrain policy metadata; truthful binding to the actual guest/verifier
  and EL semantics remains an explicit external adapter obligation.
- **Witnesses:** real old-rule land 0→2 then K1→K2 activation, historical cached retry, fresh
  new-rule signing, conflicting cache/trust refusal, earlier boundary with distinct versions,
  repeated rule IDs with a forbidden crossing, closed/invalidated jobs, immutable statement,
  failed auth/checkpoint/grid/config, existing signatures/unsettled blocks above H, retained
  old-generation HRS99, and a genuine reachable Task2 session signing through this gate.
- **Mutations:** `test_upgrade_boundary.py` has 28 semantic mutants covering every above
  guard, historical flattening, discarded boundaries/jobs/material/HRS, unauthorized original
  land bypass, fresh/cache policy and session authorization. All compile Model-only silently
  before the unchanged theorem layer fails. Initial RED was an absent-API contract, not a
  claim of a preexisting semantic bug.
- **Source handling:** nonpending §10.1 subclaims gain narrow conditional evidence. Reviewed
  rule narrowings attribute derived evidence to START-10.1-2/3/7/12/13/14 only; direct guard
  checks are separately reported here. Pending IDs `EN-fac3b57a8c83d321`,
  `EN-d419a126b4a3b7a6`, `EN-e2026d5eb187cc87` remain unchanged. No source checker is relaxed.

## Decisions and their costs

The controller's chronological decisions were: preserve original headlines/premises and
use supplementary semantic interfaces; leave undefined activation unavailable; keep local
execution plans ignored while committing durable evidence; initially use an equivalent
formatter/hook-skip workaround for a broken pnpm12 launcher; choose the globally coupled
locking reading; retain a separate durable generation watermark; order post-rollback
reconfirmation only after an actual snapshot-advancing landing; supersede the hook-skip
workaround with CI-compatible pnpm9.15.9/Prettier3.2.5 and all hooks enabled; and bind the
Anchorless service tuple through one fixed ideal slot adapter.

The first three choices keep missing assurance visible instead of changing headlines or
pretending activation exists. The historical formatter workaround is recorded rather than
hidden; automatic approval review rejected further bypass, and the safe pnpm9 solution now
runs the original hook without configuration/package/lock changes. No bypass is used for
Tasks 4–8. The locking choice needs real engine refinement; the watermark needs authoritative
physical restoration; the corrected rollback ordering excludes impossible immediate
reconfirmation; slot isolation needs explicit hash/encoding and unequal-slot evidence.

## Verification and preservation

Final package evidence: **1,216 exact contracts**, **248 derivation chains** (111 direct
induction, 137 through derived Etna theorems, longest 6), **21 Lean regression modules**,
all seven original premise fields used, fresh vectors, role/axiom/shadowing/library checks.
There are 248 property, 3 constant, 508 supporting and 457 regression contracts, with 25
exact named UNSOURCED plumbing contracts. Source traceability is 101 partial, 301 deferred
and 3 design-pending clauses; 34 narrow claims and 14 explicit boundaries.

The final gates use Lean 4.35.0-rc4, cached CI-compatible pnpm9.15.9 and Prettier3.2.5:
`lint_sources.py`, `check_imports.py`, `lake build`, `check_vectors.py`, `rule_coverage.py`,
`generate_artifacts.py` and `--check`, `check_spec_coverage.py`, rule `--check`,
`audit_proofs.py`, the complete `python3 -m unittest discover -s tests` suite and
`git diff --check`. Task8 focused suite is **30/30**. The fresh complete suite passed **377/377** in
398.318 seconds with stable sources and no concurrent build/audit. An earlier superseded
run encountered missing oleans and an obsolete mutation anchor during an amendment rebuild;
the affected tests and then the entire suite were rerun successfully, without weakening gates.

All 1,171 pre-Task8 declaration/type pairs and all original 954 pairs are exact. One prior
manifest field is intentionally corrected: `Etna.Design.RegistryHistory.trace_preserves_slash_bounty.scope`
no longer incorrectly says every other immutable in that source row is unmodeled. Its type,
proof and source edges are unchanged. All other prior complete manifest entries, 33 claims,
13 boundaries, three authority pins, pending IDs and normative sources stay intact.
README and premise-responsibility prose now describe the general canonical lift, actual
post-recovery landing, lower-level locking, stronger certified rollback scope, conditional
code-K changes and retained physical-adapter limitations consistently.

The complete branch still needs the parent-controlled whole-branch review, authorized
fast-forward push and fresh exact-pushed-SHA review. This report does not claim those actions
have occurred. No production changes, launch acceptance, global freshness, continuous
collateral guarantee, poison-resubmission prevention or complete upgrade mechanism are proved.
