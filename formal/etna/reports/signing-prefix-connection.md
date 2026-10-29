# Actual signer, trusted prefix and exit snapshot connection

Authority: SPEC.md/ACCEPTANCE.md at `39ebefbf33a2702b750e0fb0db7d2a40ff8e8480` (#22303). This extension updates the formal results of #22292. It changes no production signer, client, contract, specification or original headline premise. No superpowers design or implementation document is part of the patch.

## What is now connected

`SigningBridge.fresh_signing_connection` connects an **actual successful call of the existing `Signer.sign`** to a typed request, a replayed trusted prefix, the confirmation checkpoint and lifetime exit exclusion. A new durable-log entry distinguishes a fresh modeled signing event from a cached same-HRS return. The returned fresh signature and appended record are bound to the exact request; the request is bound to all decoded domain/generation/height/round/phase/block-id coordinates through an explicit encoder, and the device has an immutable key with a signature-authentication relation.

The node's `TrustedPrefix` contains:

- The fixed deployment configuration and an actual successful `HistoricalContext.build` over the view's typed registry history and a shared anchor archive.
- Replay from the fixed origin with its retained record, a valid decoded chain matching the authenticated target's height, **EL hash, CometBFT hash and FI cursor**, and a valid extension to the local committed tip.
- Actual `NodeValid` checks and own-finalized anchor predicates for every block, a present local header for each checkpoint fence, sufficient archive coverage, and a reference number no later than the observed own-finalized view.
- A snapshot source: the exact initialization floor or an actual accepted valid batch with its certificate bound to that batch's terminal fields. Framed sources preserve the checkpoint/snapshot across registry, fee or nonce changes. An older certified landing before a newer recovery origin can use the new generation's floor; this requires the separately stated certificate reference bound and L1 ordering.

`IncludedCheckpoint` locates the confirmation checkpoint inside this same replay with matching full checkpoint fields and source history. The request producer's `EngineRequest` binds the actual decoded message to the prefix's domain/generation, **local committed tip + 1**, and the actual selected key membership. Nil votes and retained candidates at the active consensus height use the same height and committee requirement. Old-height cached retries remain a separate signer behavior.

The proof then derives, rather than assumes:

```text
accepted source batch + matching checkpoint on the replay
  -> confirmation checkpoint height <= local tip
  -> selected cutoff at that checkpoint <= selected cutoff at actual request height
  -> confirmed exit E <= request selection cutoff
  -> exited lifetime key absent from that committee
  -> a bound engine request / successful observed signing call uses a different key
```

The cutoff order comes from the actual selector, fixed origin and monotone archive, including the initial-to-ordinary and recovery-to-ordinary handovers. `SameSigningHistory` supplies common selection coordinates and anchor lookups, without requiring whole registry functions to be equal. The additional `extendedArchive` source and `SigningPrefix.extended_archive_cutoff` prove transport when future headers are appended to a covered old archive, even as registry history advances. They do not authenticate a replaced archive or transport across a fork. There is no input hypothesis of selected-cutoff >= stored snapshot, key exclusion, a live bond or positive collateral. Snapshot provenance, real prefix inclusion, initial structural invariants and producer/adapter behavior remain explicit inputs.

The general event theorem permits genuine initialized registries with established lifetime-key and exit-history invariants. Its zero-slot corollary derives these invariants from the configured initial lifecycle. The positive witness instantiates the general theorem from the actual non-vacuity `Deployment.Genesis`, through ordinary rotation, confirmation and withdrawal, with a complete trusted prefix and a fresh key-8 precommit at height 13. Computable decoded adapter fixtures also cover the three signing phases; they do not implement real canonical sign bytes or cryptography.

## Conditions supplied by the design versus missing enforcement

SPEC 4.3, 8.2 and 9 require the authenticated origin/committee, exact checkpoint trust, own-finalized anchors, retained durable HRS state and per-request trust gate. The new model spells out their request/prefix/key/bytes relationships. Stock Comet/app integration must still establish `EngineRequest`, canonical decoding and the immutable device-key binding for every real call. `Signer.sign`'s `ready`/`trusted` booleans alone do not establish those facts. This checkout contains no Etna guarded signer/ABCI implementation proving that refinement; no production implementation is certified by these theorems. Real L1/MPT/header/EL and signature authentication remain external adapter obligations.

**An own-finalized view is not the latest global L1 World.** SPEC 9 says to authenticate the latest checkpoint in the node's own finalized view; it does not give a numerical freshness bound or require that view to contain every newer exit confirmation/withdrawal. To claim exclusion relative to a particular confirmation, the node's authenticated view must causally follow that confirmation and its replay must include the corresponding checkpoint/source. Neither follows merely from a session being trusted.

A stronger global post-withdrawal prohibition would need an additional condition such as authenticated catch-up covering the relevant confirmation checkpoint before new signing, with a defined freshness/revocation rule relating session authorization to newer L1 state. A wall-clock age bound alone needs an explicit bound on L1 finality/observation lag and on checkpoint propagation. This patch does not silently add such a signer veto.

The current `IncludedCheckpoint` path locates the confirmation inside the replay from this generation's fixed origin. If a recovery starts above an older confirmation checkpoint, a retained-checkpoint ancestry or equivalent authenticated exit-coverage refinement must discharge that relation; this patch does not infer it from a trusted boolean or claim arbitrary cross-generation replay completeness. The recovery-floor source handles its stated temporal provenance conditions.

**Rollback needs authentic provenance and renewed trust.** The source must be the actual last-trusted landing (or initialization), with the specified confirmation recheck and the correct generation origin. An arbitrary numeric restored snapshot is insufficient. Existing sessions must be tied to the post-rollback canonical prefix; the design says node rollback rules ship with the upgrade but does not specify a complete session-token invalidation protocol here. No generic theorem covers unrestricted `applyRollback` inputs or an unrevalidated old session.

**Continuous positive backing remains false.** Full slashing can empty principal before fixed committee power changes. Connecting fresh signing to the correct committee does not restore already exhausted collateral, and this extension makes no continuous-capital claim. Evidence delivery and timely governance action also remain operational conditions.

## Checked stale-view counterexample

`SigningViewLag` now inhabits the full typed prefix, actual call and request producer predicates:

1. The reachable own-finalized view is L1 block 26, with checkpoint 0 and snapshot 12. The local prefix is valid through height 9; all its anchors and the previously signed height-10 block are at or before that finalized source.
2. The signer retains ten authoritative precommits, including height 10 / round 0 / precommit. It has not learned the network's commit and may move to round 1 at its local next height 10.
3. Other nodes land checkpoint 12 at L1 29, confirm the old key's exit and complete the fixture's full withdrawal delay at L1 30. The old key has zero principal and is released.
4. With the lagging view, the existing stock signer freshly appends a **height-10 / round-1 nil precommit**. This is HRS-forward and not a cached return, state reset or same-round double sign. Its message, immutable key and signature relation use the full decoded adapter.
5. The newer checkpoint cannot be in this local replay: its height is 12 while the local tip is 9. The view also predates the confirmation. Thus the theorem's confirmation-to-view and inclusion conditions are not available.

This refutes an unqualified claim that no new signature can be created after global withdrawal. It does **not** demonstrate an extension above the latest global checkpoint, a violation of same-round finality or a SPEC-compliant fund-stealing attack. The request is below the newer checkpoint; the checkpoint fence is precisely what distinguishes historical/lagging activity from a trusted current extension.

## Validation

The central gate passed with pinned Lean 4.35.0-rc4: a clean 101-job build, 894 exact theorem contracts, 154 mechanical property derivation chains, 12 silently replayed Lean regression modules, all 172 Python tests, standard axioms only, fresh kernel replay and unchanged seven-field headline premise use. All 754 vectors match a fresh generator run and source/artifact checks pass. Targeted positive and stale-view witnesses also compile. Independent kernel mutations check the two checkpoint hashes, actual message height/bytes, local-tip ordering, key membership and shared archive. Exact types, mechanical roles, standard axioms, fresh kernel replay, unchanged headline premises, source pins, vectors and the full Python suite are checked by the central gate. Final totals and results are recorded in the package README.
