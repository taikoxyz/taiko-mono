# Etna anchor, proof and recovery product

The user authorized a summary and continued formal verification. The previous
Free operational-view stage remains delivered with its original safety objective
OPEN. This new stage targets interactions omitted by immediate anchor adoption
and tip-only landing. Design source is unmerged PR22425 at `178d7a7a`, main
`360262975`; the formal branch baseline is `f5ca696e1`.

## Objective and evidence

Build a separate source-qualified finite TLA product that distinguishes the
actual L1 Inbox/checkpoint state, a node's own finalized view, and the anchor
adopted by each L2 block. Bind an immutable full proof range to execution-time
actual c. Compose pending checkpoint comparisons and signing, saved-state
recovery, frozen origin fallback, and subsequent anchor-driven selection.

Success requires a completed finite micro graph, source-valid positive paths
and literal raw-state readback, meaningful semantic faults/restoration, complete
producer provenance and independent source review. Larger searches retain their
actual status; no finite result or case count proves the whole protocol.

## Approaches and root choice

1. Extend the previous committee kernel: its live env, latest-c backpressure,
   tip-only landing and immediate recovery erase the very distinctions needed.
2. Reuse historical proving products wholesale: their statement writers contain
   historical activeSnapshot/dependency fields absent from draft178.
3. Add a distinct product with narrow pure-operator reuse and explicit contracts.
   Root selects this approach. Old models, fixtures, claims and classifications
   remain byte-identical. Their old results are historical contracts, not new
   protocol coverage.

The existing workflow and user's repeated opt-out from planning questions apply.
No further approval or execution-method question is required. Root owns choices
not fixed by source and records their costs in the ignored stage ledger.

## State and contracts

- One immutable canonical L1 snapshot stream records number, time, generation,
  current M/F, c and its exact EL/Comet/FI tuple, per-height landing records,
  nonce, origin records and SignalService. Sparse named L1 heights avoid
  enumerating an outage of hundreds of thousands of blocks.
- A node tracks its own finalized snapshot, local committed history, actual
  retained candidate, pending target and EL/Comet comparison stage, plus trust.
  Reads unavailable preserve known targets. Generation-only advancement revokes
  old-domain trust. At a generation's origin only EL is compared locally;
  subsequent checkpoints require both hashes from the same pinned finalized view.
- Every proposed header names its own anchor. New or inherited witness rules,
  monotonic origin floor, candidate-time age and anchor-proven c+U apply. Today's
  Inbox M/F/c cannot replace a retained header's historical choices.
- Proof jobs freeze generation/origin, p,h, reference, full ordered blocks/data,
  full interior cuts and statement identity. Guest validity is an explicit
  sound-proof/STF/certificate contract, independent of today's actual c and local
  node tip. L1 compares the entire cut at actual c and applies only the suffix.
  Every height may become a checkpoint; record parent is previous actual c.
- The p-only root exception authenticates p's M/F solely for p+2 membership.
  Every newly covered anchor, including an inherited one, still requires
  ordinary ancestry. No exact ABI/hash/cryptography implementation is claimed.
- Recover executes against actual c/generation/nonce, preserves c/FI/prefix,
  freezes R/F and raises generation. Later observation and bootstrap restore
  the saved checkpoint's EL state, discard old pending state and reset the first
  Comet link. Later fallback rotation cannot rewrite the first two signers.

Pure Decision/Choice/Quorum/Updates operators from the frozen kernel may be
instantiated with explicit bindings. Never invoke its operational Next/Commit/
Land/Recover or copy a historical proof-statement writer.

## Independent literal fixtures

The source oracle was frozen before any new model: 21 main events,15 trust-gate
observations,8 alternative histories and5 semantic control groups. Parameters
include S10/U3, four unit bonds and two four-key fallback lists, maxBatchBlocks2,
maxAnchorAge86400s, supported ancestry budget131072 and readable reference
window8191. Main roots O100/A200/B320/C600/J820/L930/R141000/Z141100 bind
the source's M/F, checkpoint and nonzero FI cursor transitions.

H15 is not discarded simply because unlanded. Under an explicit independent
outage, at inclusion N140000 every readable reference r>=131809 has
r-600>=131209>131072. Earlier compatible references expired, so ordinary
proofs containing H15 cannot land. H15 was valid at its own timestamp; the
p-only exception cannot authenticate its new-block inherited anchor. Recovery
also assumes audited prefix14, ready independent controllers and governance.
If H15 remains settleable, land it first and preserve its exit at recovery15.

Separate supplements cover a small complete micro graph and p>o's old-root
exception with fresh ordinary anchors. Independently certified divergent
Comet histories are adversarial contract inputs, outside normal <1/3 quorum
safety. Fabricated leaf mutations are interface controls and never protocol
counterexamples. Source validity and these premises need review before engine GO.

## Observers, bounds and verification

Use one normal micro graph and fixed finite external-offer profiles for larger
interleavings. Offers are inputs, not expected results or endpoint flags. Never
remove a required normal action merely to finish a graph. A retained candidate
is captured once; its timestamp/anchor/content do not change when local finality
advances. Positive observations cannot authorize transitions.

Retain all operative state in a view, plus actual safety and named observation
truth values if receipts are omitted. Next cannot read old receipts. Prove the
same-state/same-input lifting and first-failure argument before such a view is
used. No native symmetry, fairness or liveness claim is implied.

Runtime uses existing pinned TLC/JRE,45s per case,512MiB,one worker,seed1,
offline read-only source and disposable output. Root alone gives engine GO.
Root first observes a wrong normal Fault=None anchor-pressure RED, then author repairs the same normal guard and focused
checks go GREEN. Missing-action and semantic controls require actual raw output,
not parser errors, metadata edits or intended outcomes.

## Publication and limits

The existing draft branch and owned PR/issue prefix are the publication target.
No production/SPEC/Notion changes, external comments/reviews, new dependencies,
signing/keys, live chains, node/EL/Go engines, deploy/merge/ready actions. Preserve
all previous artifacts, original timeouts, runtime WAITING and historical
INCONCLUSIVE rows. Root publishes only after independent gates; exact-head CI,
official artifact digests and semantic readback remain post-commit requirements.

## Builder-review resolutions before implementation

Every canonical L1 snapshot is built from that run's actual transitions and
has a branch-local immutable identity derived from its number, parent identity,
actual protocol-storage projection and input/outcome. Sharing a numeric L1
height does not share a root after histories diverge. J/L labels describe only
the short-first fixture. Own-finalized targets and slot285 comparisons stay at
the exact selected snapshot identity. Main selects an immutable external script
ID at Init (or an equivalent input prefix tree), preserved by state/VIEW, so
short-first and direct-long are both real selectable histories.

Micro must produce nine actual two-slot paths, including idle and rejected
second offers. Private named probes or actual edge export check input500,
outcome500 and input600,outcome600 and both intermediate/final stored values
against the frozen supplement. Deleting a stale second-offer branch must make
coverage fail. This is separate from normal safety-graph completion.

The initial scaffold's normal Fault=None pressure guard is wrong. Run the SAME
normal configuration/input sequence before and after repair: AnchorFenceSafe
fails before; the repaired graph has no such failure and its actual14/B offer
is refused. The permanent Fault=LatestC profile remains a separate mutant,
with its own source/config identity. Do not call changing that flag a repair.

Atomic refusal preserves Inbox, records, FI, SignalService, jobs and local state,
while the containing canonical L1 block number/history and an external input
slot may advance. Those environment fields are framed separately. Put stale
expectedC12 recovery at1000, leaving fresh R141000 available.

The original old-domain jobs are compound stale-range/reference examples.
Isolated proof-generation-binding sensitivity remains OPEN unless a separately
reviewed one-field authentication interface control is supplied; do not claim
it from those jobs. The positive generation1 retained-origin job is required.

This product verifies app gate admission/status. Pending gate probes do not
represent an actual refused Comet RPC. Actual signatures are admitted only at
a fully matched, externally authenticated session; end-to-end refusal/timeout,
WAL/HRS replay and guarded supervisor restart remain external contracts. A
sequence that issues a real refusal must explicitly include successful guarded
rebind before later signing, otherwise label it unverified. No such runtime
recovery claim is gained by this finite gate model.
