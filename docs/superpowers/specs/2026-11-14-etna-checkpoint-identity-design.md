# Etna checkpoint identity TLA+ extension

## Agreed scope and approach

Continue the existing `formal/etna/` project and local branch. The user approved
adding checkpoint/cut identity, competing candidate histories and recovery
boundary preservation. The source is still Etna `SPEC.md` at main
`d18357214fab30ea512ae9858a11699806d72ba1` (rechecked 2026-11-14).

Compose a new top-level module with the existing `EtnaSettlement` actions rather
than rewrite the first model or start another project. Its original module and
12 configurations remain unchanged. Replacing the small model would lose a
useful regression boundary; modeling consensus/L1 views now would exceed this
increment. The root chooses the composition interfaces below.

## State and transitions

Use symbolic identities for a cut's height, EL hash, Comet hash, FI head and
validator-state hash, matching ENC-A-29/30 and normative land steps 2/3/6. Hashes
are collision-free symbolic values; ABI encoding and cryptographic soundness are
assumptions, not checked algorithms.

Represent two finite candidate histories with a configurable common prefix and
fork point. A field parameter may isolate EL, Comet, FI or validator-state
differences to check the whole cut interface. Such inputs overapproximate the
boundary metadata; no claim is made that independently varied fields have
production EVM/Comet preimages or valid honest-quorum certificates.

Retain symbolic identities for actual landing records and an observation-only
settled prefix. A queued proof has a height/generation envelope from the base
model, an executed-history identity and separately supplied cut leaves. Preparing
an input does not assert the L1 contract will accept it. This permits wrong-origin,
cross-fork and substituted-leaf attempts to be explored.

Wrapped land checks the base action plus: proof origin/public-input binding to the
retained record; supplied cut at actual c matching the full checkpoint when c>p;
and every supplied interior cut matching the execution-authenticated cuts.
Only the suffix `(c,h]` updates the settled prefix. Landing records use actual c
as parent. Recovery uses the base action and preserves identity records and the
settled prefix.

Important origin exception: current-generation start p may reuse an old-generation
record. Its retained public-input boundary is not the new generation's initial
validator state. PROOF-6.2-41a reconstructs that state from genesis, so the model
must not demand equality between it and the old record's validator-state hash.
Guest genesis derivation remains an explicit assumption; full cut comparisons at
interior checkpoints have no such exception.

## Checks

- Origin/public-input identity and execution-authenticated interior cuts cannot
  be substituted by another history's values.
- A successful overlapping landing agrees with the full existing checkpoint,
  not merely height or EL hash.
- Accepted suffixes remain compatible with one candidate history and cannot
  replace the settled prefix; recovery preserves the retained identity.
- Positive witnesses reach valid same-history overlap, a conflicting queued
  overlap, substituted leaves, recovery and post-recovery landing using the
  retained older origin record. Shared-prefix histories can diverge after c.
- Independent missing-origin, missing-boundary, missing-cut-binding and
  recovery-identity-rewrite controls must fail their intended invariants.
  An EL-only boundary comparison must fail when another cut component differs.

Audit state observes transitions but never enables them. Model bounds normalize
the grid to K=1. No fairness, liveness, L1 fork, signer, committee/STF or actual
implementation-equivalence claim is introduced.

## Delivery and validation

Keep one runner and add an optional strict `MODULE` comment to configurations;
old configs default to `EtnaSettlement`. Validate module names and local file
existence. Add tests for malformed/duplicate/unsafe module selection and retain
all existing outcome checks. No tool download or production compilation.

Run all old and new configurations, a stronger independent bounded check,
negative-control trace inspection and source/model correspondence review.
Report exact bounds, module hashes, observed results and remaining assumptions.
Preserve counterexamples as text logs and explain at least one complete path.
Keep the changes local; no PR, merge or deployment is requested.
