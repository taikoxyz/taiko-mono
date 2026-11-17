# Etna coverage closure design

## Intent and authorization

The user approved organizing remaining obligations into executable tasks and
starting the next five increments. The previous F01-F05 batch is complete at
`6057aee347f4865830593f1775e99b4f4822f96c`. Preserve the existing isolated branch,
draft PR22387, pins, artifacts and hourly feedback workflow. No additional design
approval is needed for this accepted continuation. New scope choices below are
engineering decisions, not claims that the user selected individual test APIs.

The immediate objective is to reduce untested implementation and composition
assumptions, while making remaining obligations and completion evidence visible.

## Approach

Use one current remaining-work index at `formal/etna/WORKLIST.md`, with module
ownership, acceptance, dependencies and a minimum composition matrix. Keep issue
22355 as the concise GitHub entry point and preserve earlier reports as history.
Do not turn the four aggregate unassessed mutation rows into four vague tasks,
or the 19 archived incomplete prototypes into a mandatory obsolete rerun queue.

The alternatives were more repetitions of existing green profiles, or immediate
full client/prover integration. Repetition cannot remove shared premises; a full
integration lane needs Etna APIs and real proving/runtime inputs not currently
established. Choose two selected real stock boundaries plus two actual-model
compositions, with a CI gate to retain the evidence. Broader runtime obligations
remain explicitly waiting on concrete implementations.

## Five deliverables

- G01: a draft-enabled, bounded TLC/Python CI lane with pinned tool bytes and
  fail-closed result handling. No native/contract/proof acceptance is inferred.
- G02: completed stock Bootstrap survives process termination and real on-disk
  DB reopening, preserving selected literal state and validator-history fields.
  This is process-restart evidence, not physical power-loss or multi-store atomicity.
- G03: actual stock `HandshakeWithContext` height/AppHash matrix, including the
  empty-blockstore branch and typed disagreement refusals. Explicit mock App Info
  responses do not become real Etna EL persistence evidence.
- G04: held positive-stop programs also queue/attempt an old proof around actual
  recovery actions, with live references and exact terminal/progress receipts.
- G05: a namespaced instance of actual M03 signer actions composed with selected
  stop/recovery observations; computed/persisted work, restart and exposure are
  audited independently. External authentication remains an explicit premise.

## Constraints and validation

Keep normative SPEC commit `d18357214fab30ea512ae9858a11699806d72ba1`, contract
commit `89f419915de4b73bb57c53bf970f6dea9e8e8c8c`, and CometBFT v0.40.0 commit
`0880b4d378f347ab16e54ec677ff50d803f37d62`. TLC release1.7.4 jar SHA256 is
`936a262061c914694dfd669a543be24573c45d5aa0ff20a8b96b23d01e050e88`.
Preserve 369 pre-batch config bytes and all archived experiments. Extend selected
models only where a new scenario needs it; do not duplicate an operational engine.

Use configured Python, Java17+, existing Go SDK/module cache and the one existing
physical Go build cache/lock. Inspect entrypoints before isolated offline runs;
source/dependencies read-only, disposable writable outputs, no original Git/home,
secret variables, keys, signing, installation or broadcasts. Fetch dependencies
only in a separate bounded preparation step if inspection proves it necessary.

Each task needs independent source/spec review and independent meaningful
behavioral verification, intended-failure controls, exact test identities,
current executed input hashes and actual same-copy restoration. Two material
fix iterations maximum before a root ruling; unresolved material issues cannot
be pushed as passing. Existing feedback is evaluated first. Final review checks
the complete new batch and actual raw results. Never substitute setup/timeout/
wrong-reason failure for a semantic result. Keep measured and historical evidence
separate, including native tests affected by later formatting hooks.

Root owns WORKLIST/README/REPORT, shared inventory/cohorts, publication, issue
updates and durable runtime progress. Implementers own only assigned task files;
one implementer at a time, no nested agents. Reviewers/testers do not author the
final implementation they assess. Preserve existing review/test caches and all
evidence while the draft remains open. Stop after five; no merge, mark-ready,
production/SPEC/Notion changes or deployment.
