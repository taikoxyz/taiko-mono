# Slot-Chain — Taiko preconfirmation protocol (v2 design)

This directory holds the design specification for Taiko's v2 preconfirmation protocol, together
with the executable models that verify its consensus-critical arithmetic.

## Contents

| File | What it is |
| --- | --- |
| [`slot-chain-spec.pdf`](slot-chain-spec.pdf) | **The specification.** A4, single column. This is the artifact to read and circulate. |
| [`tex/main.tex`](tex/main.tex) | **The source.** Hand-maintained LaTeX; edit this to change the document. |
| [`settlement-window-model.py`](settlement-window-model.py) | Unified mode machine: two-phase fork-bound normal contexts, stale-arm replacement, canonical EVM height/context plus terminal root/count, exact slot time, EIP-2935/G_MAX boundaries, explicit state-witness and bytecode availability, durable depth-64 queue descriptors and conserved fee custody, renewable recovery, bounded payload loss, fixed liability ring, same-L1 direct bridge enqueue, immutable authorization versus mutable liability, frozen Bridge/vault facades, aggregate ETH/token solvency, quota-independent refunds, selector-explicit refund modes/capsules, single-word finalized destination registration, complete value-carrying release manifests, fresh/exact-reuse endpoint activation, fork-proof legacy proxy attestation and immutable fresh facades, immutable destination pins, exact inbox/terminal ABIs, global mixed-domain inbox application, per-Settlement canonical history, historical accumulator proofs, one live ForcedQueue and cursor, authenticated router-owned migration generations, reservation-preserving protocol-lifetime schedules, atomic manifest-Anchor activation on every release, bridged-token restoration, capacity and enqueue/cancel races, persistent SYNCED refund/retry, PREACTIVE ingress, L2 activation gating, migration and reorg replay. 178 assertions. |
| [`lookahead-model.py`](lookahead-model.py) | Exact lookahead path: absolute clock conversion, EIP-4788 carrier/parent semantics, execution-block finality, partial/empty registries, frozen-context tombstones, capped quotas, ring capacity and placement. 36 assertions. |
| [`commitment-model.py`](commitment-model.py) | Byte-exact fixtures for split chain domains, EIP-712, release-bound statements, canonical/statement/single- and multi-block candidates/winning/migration data, complete kind-0/kind-1 durable descriptors and dispositions, a depth-64 forced vector and queue configuration hash, same-L1 source and permanent destination domains, acyclic Bridge-kernel/frozen source facade/complete destination facade/nine-component infrastructure descriptors with explicit Bridge topology, bounded-chain-ID release manifests, profile dependency rejection and single-word destination-registration commitments/slots plus inbox-route configuration, generation/Bridge/destination-bound credits, escrow, immutable inbox slots, DONE/FAILED terminal leaves, immutable completed-subtree nodes and historical depth-64 vector proofs, published-vector consistency, empty escape values, stable admission identity, registry/entry/tranche, per-block manifests, sessions and blobs. 161 vectors/properties. |

## Building the PDF

`main.tex` is self-contained — the TikZ figures live inline in it, and no generator is involved.

```sh
cd tex && tectonic main.tex
cp main.pdf ../slot-chain-spec.pdf
```

Tectonic automatically performs the passes needed to settle the table of contents and
cross-references. `xelatex`/`pdflatex` also work with repeated passes. The committed
`slot-chain-spec.pdf` is a copy of `tex/main.pdf`.

The committed artifact is built with Tectonic/xdvipdfmx and currently uses PDF 1.5. Rebuilders
must visually inspect the schedule, state-machine, liveness, slashing and parameter-table pages;
a successful LaTeX exit status alone is not layout verification.

## Running the models

```sh
python3 settlement-window-model.py   # 178 assertions
python3 lookahead-model.py           # 36 assertions
python3 commitment-model.py          # 161 vectors/properties
```

All run standalone and print `ALL PROPERTIES PASS` when every assertion holds. The lookahead
model has a pure-Python Ethereum Keccak implementation and uses PyCryptodome only as an optional
speedup. Signatures, validity proofs, EVM gas and execution remain placeholders in the settlement
model. **Every consensus change must update the relevant model in the same commit.** A passing
model is regression evidence, not a proof of protocol soundness.

## Status

The architecture is an **audited design candidate**, not an implementation-ready or
production-ready specification. Its remaining blocker is the absent initial executable execution
profile and its independently reproduced conformance bundle; Section 13 states why inventing that
implementation-dependent artifact in prose would be unsafe. Seven later measurable release gates
cover proof performance, contract gas, cryptographic conformance, state-machine verification,
economics, operations and external review. Five properties are worth knowing before reading:

- **Landing is permissionless.** A block's authority comes from its builder's signature, not from
  whoever carries it to L1. The aggregator is a paid service role, not a gatekeeper.
- **There is a builder-independent censorship floor.** A prepaid L1 forced-message queue opens
  recovery when its head becomes due. Anyone can prove an unsigned deterministic escape block,
  even if every builder colludes and no aggregator seat exists.
- **Recovery expires unfinalized preconfirmations.** At an objective SLA/force boundary, one
  episode restores finality with the first valid signed or unsigned proof. Its deterministic
  round can be renewed only after objective expiry, so a long prover outage cannot permanently
  stale the target. Progress still requires a root-verifiable canonical prestate package containing
  trie nodes **and runtime-bytecode preimages**; a state root alone cannot reconstruct data or code
  after every archive copy is lost. Omitted promises expire.
- **A builder's signature does not attest that the block executes.** It attests authorship and the
  choice of parent. Executability is established only by the validity proof at landing, so a
  preconfirmation is a commitment to include and to order (§9).
- **Bridge ingress has a separate availability boundary.** Launch supports only L1-to-L2 messages
  whose source registry and queue adapter share settlement Ethereum. Anyone can direct-read the
  permanent source record and atomically enqueue with a caller-funded deposit; a maintenance sync
  commits while the full deposit becomes withdrawable, then the caller retries. Missing Message
  bytes lead to permissionless source cancellation after `enqueueBy`, or destination `FAILED`
  after the immutable pin store's `processBy`. Direct and vault V2 sends use distinct additive
  selectors; the old send selector remains exact V1. V2 custody/recovery facades and stores are
  frozen and never delegatecall mutable executors. Terminal outcomes enter a protocol-lifetime
  vector whose immutable leaves and completed subtrees reconstruct historical-prefix proofs against
  each Settlement's internally written version/sequence history; reserved refunds remain usable
  through guardian pauses and zero ordinary quotas.
  Destination processing is local-domain-bound and source enablement waits for finalized one-shot L2
  registrar proof plus finality. A post-cutover L2 activation gate excludes legacy calls from V2.
  Cross-L1 kind-1 ingress is not part of this version.

Final acceptance requires a human safety review. The models and the specification are a gate, not
a signature.
