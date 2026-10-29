# Align Etna formal verification with the latest design

## Intent and authority

Update PR #22292 to follow PR #22303's existing design, rather than invent a new protocol design. The source is commit `39ebefbf33a2702b750e0fb0db7d2a40ff8e8480`:

- `packages/protocol/docs/etna-pos-zk/SPEC.md`, SHA-256 `8fe38cbd0acb08e0ec838ac064de198e2c32494d9ca2f71b4d0f773804cf37d5`.
- `packages/protocol/docs/etna-pos-zk/ACCEPTANCE.md`, SHA-256 `876f89892acc91508fd322b4df676a0eb19550b39c9a43490376b4a3b4863c60`.

The formal PR currently ends at `c9708e76159bb8da701f8bc20c07ff2e46537642`. It refers to removed `sources/spec.md` and `sources/manifest.json` and models older staking/recovery rules. The repository specification takes precedence over old README summaries and reports. Recheck #22303's head before finishing and review any additional delta before claiming alignment.

## Scope and success

Update the decoded Lean state machine, general proofs, concrete witnesses, audit and traceability tooling, conformance vectors, CI, current documentation and the existing PR description. Preserve the five-library dependency direction and exact-type, premise-use and kernel audits. Every changed source link must be reviewed and the complete formal gate must pass.

Keep H1 fund safety, H2 same-round accountable finality and H3 forced-inclusion integrity under explicit premises. Extend them over all new public transitions; do not exclude top-ups, forfeiture or nonce invalidation from traces to preserve proofs. H2 must cover all remaining principal, including pending top-ups, rather than only effective stake. Do not add economic sufficiency premises to H1-H3.

Production contracts, clients, guests, deployments and source-specification edits are outside scope. Regenerating formal vectors does not establish production conformance. Preserve historical conformance results with their old revision and distinguish new cases awaiting downstream harness adoption.

## Staking and delayed top-ups: SPEC 4.1

Add pending principal and its ready L1 block to entry accounting without adding them to committee entry encoding. Model topUp and activateTopUp as real registry operations, including before Inbox initialization. Deposit requires the entry owner, an unreleased already-active entry with positive effective stake, no exit, no pending deposit and positive amount. Reject uint256 balance overflow and uint48 ready-block overflow, reading activationDelay from the registry's fixed configuration.

Only explicit successful activation after readiness moves pending principal into effective stake and creates the normal entry checkpoint. Deposit and maturity alone do not change committee history. Activation leaves old checkpoints and already-derived committees intact. Once exit is set, both operations reject. Full allocation of all 4096 slots does not prevent top-ups.

Define remaining principal as effective stake plus pending principal. Withdrawal requires the owner whenever the sum is positive, pays the entire sum, and clears pending accounting/readiness on release. Double-sign slashing consumes the entire sum, clears readiness, and computes the existing bounty/sink split from the sum. Existing admissible evidence stays usable after later deposits and DAO forfeiture. Recovery exclusion alone preserves all principal.

## DAO responsibility forfeiture: SPEC 4.4

Model the registry-owner operation with entry identity, incident id, expiry and fixed valid forfeitBps. As with the existing decoded recovery owner check, authority is an authenticated owner boundary, not proof of a DAO proposal lifecycle or attribution correctness.

Require initialization, no reentrant call, matching unreleased entry, unset lifetime flag, positive remaining principal and execution timestamp at or before validUntil. Compute `ceil(balance * forfeitBps / 10000)` with `0 < forfeitBps <= 10000`. Deduct effective stake first, then pending principal; clear readiness if pending reaches zero. Pay the entire penalty to the sink, with no bounty, and force exit at min(old exit, current L1 block). Preserve an existing exit confirmation and its clock.

Set the lifetime entryKey flag atomically. Preserve it through release, reuse and verifier-failure rollback. Failed external effects leave no partial deduction, flag or exit change. Deposits after authorization and before execution count in the penalty. Reusing an incident id on different entries is allowed.

There is no forfeiture nonce, cancellation, scheduling state or added waiting period. Landing, recovery and generation changes do not invalidate authorization. Recovery and forfeiture are independent transactions; recovery does not wait for or perform the deduction. Cover transaction ordering with withdrawal, double-sign slashing, top-ups and recovery. Deadlines use L1 Unix seconds; delays/readiness use L1 blocks.

## Recovery authorization: SPEC 8, 8.3 and appendix B

Add uint256 recoveryNonce to Inbox state, initially zero. Extend requests with expectedRecoveryNonce and validUntil. Require Inbox initialization, matching generation/checkpoint/nonce and timestamp at or before expiry, alongside existing list/atomicity checks. Successful recovery increments generation and nonce with their respective width checks.

Add initialized owner-only invalidateRecoveryNonce(expectedRecoveryNonce), with exact match and overflow checks, as a protocol step. It changes neither settlement nor committee history, FI state or registry principal. Verifier-failure rollback increments the current nonce, never restores a historical nonce, and fails atomically at overflow. Model that failure explicitly rather than allowing an unbounded or wrapping successful rollback. Ordinary landing does not increment the nonce.

Replace the current-design finding StaleDaoAuthorization.stale_authorization_revives with a kernel-checked non-revival regression. Keep old explanations explicitly historical. Prove nonce monotonicity and non-revival generally, and exercise expiry equality, invalidation, replay, initialization and overflow concretely.

## Capital acceptance, separate from validity

Add pure definitions and arithmetic results for ACCEPTANCE section 4. With positive C_CAP_MIN and P_REF in the specified units, compute `S_MIN_TOTAL = ceil(3 * C_CAP_MIN * 10^18 / P_REF)`. Initial acceptance checks the actual selected committee, excluding unselected and pending stake, using both:

- `sum(selected effStake) >= S_MIN_TOTAL`.
- `ceil(totalPower / 3) * vp_unit * P_REF >= C_CAP_MIN * 10^18`.

Represent the strict concentration bounds for each entry and known common-control aggregate. Price sources, validity/review policy and common-control identity remain external operating evidence. Neither a capital shortfall nor expired valuation becomes a guard on build, validation, rotation, recovery or signing. Claim no acquisition-cost, irreversible-loss or guaranteed timely-DAO-response result.

## Proofs, witnesses and traceability

Update structural invariants and all step inductions for new balances, operations and nonce invalidation. Preserve registry history and the distinction between effective stake and metadata. Rebuild H1-H3, their conjunction and non-vacuity without opaque axioms, admitted proofs or audit bypasses. Reassess remaining counterexamples under the new semantics: nonce protection alone does not fix recovery committee capture or FI poison resubmission.

Pin the SPEC path/bytes directly and remove reliance on the deleted source manifest. Also pin ACCEPTANCE because the new capital definitions depend on it. The builder may choose a minimal inventory-schema extension; any unreviewed edit to either source must fail closed. Review changed content identities and refresh live line citations, theorem contracts, mechanical roles, narrow-claim evidence, pending statuses and measured counts. Preserve historical source references only when explicitly dated.

Generate new registry/recovery vectors for interfaces and failure boundaries while preserving recognizable existing cases where behavior is unchanged. Document vector-schema changes and downstream harness obligations. ABI, ERC-7201 storage layouts, events, transfers and cryptography beyond what the decoded generator actually checks stay explicit deferred obligations; logical field modelling is not byte-layout conformance.

Update both CI path filters for the current specification and checklist. Refresh README, reports and PR #22292's description with the actual source commit, theorem scope and measured verification results. Historical report counts can remain when clearly dated; live claims cannot.

## Validation and delivery

Start with failing Lean regressions and Python mutation tests for new behavior, then implement. Run the complete sequence from formal/etna: source lint, import graph, pinned-toolchain lake build, fresh vector check, artifact generation and deterministic check, source coverage, proof audit with fresh kernel replay, and all Python/Lean regressions. Regenerate and review audit data without relaxing the gate.

Use the existing Lean 4.35.0-rc4 standard-library-only toolchain and Python standard library. No new dependencies. Run git diff --check and inspect the final PR diff against the latest #22303 head. Update the existing PR after verification, without merging it.

## Proposed builder decisions

These are my proposed choices, not choices supplied by the user:

- Merge the latest base from #22303 into #22292, preserving its current commits and avoiding remote history rewriting.
- Put capital arithmetic in a focused model/proof pair outside validity guards; choose exact module/helper names during implementation.
- Preserve the decoded model's authenticated-authority and external-effect boundaries, documenting their limits instead of modelling DAO/ERC20 runtimes.
- Extend evidence/vector formats only as needed and document downstream obligations.

This is a local design artifact for review. Implementation planning and product-code edits follow approval of this description, as required by the explicitly invoked brainstorming skill. Execution plans remain untracked, following formal/etna/README.md.
