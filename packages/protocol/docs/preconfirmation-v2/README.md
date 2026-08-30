# Slot-Chain — Taiko preconfirmation protocol (v2 design)

This directory holds the design specification for Taiko's v2 preconfirmation protocol, together
with the executable models that verify its consensus-critical arithmetic.

## Contents

| File                                                       | What it is                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| ---------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [`slot-chain-spec.pdf`](slot-chain-spec.pdf)               | **The specification.** A4, single column. This is the artifact to read and circulate.                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| [`tex/main.tex`](tex/main.tex)                             | **The source.** Hand-maintained LaTeX; edit this to change the document.                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| [`settlement-window-model.py`](settlement-window-model.py) | Unified protocol/state model for proof-first launch and migration, continuous seat scheduling, forced-queue recovery, same-L1 DIRECT ETH ingress, fresh immutable V2 endpoints, permanent inbox pins, permissionless LP-owned atomic-funding tickets, source user/LP pull conservation, terminal frontier proofs, historical destination retirement, and atomic rollback/reorg behavior.                                                                                                                                               |
| [`lookahead-model.py`](lookahead-model.py)                 | Exact lookahead path: absolute clock conversion, EIP-4788 carrier/parent semantics, execution-block finality, partial/empty registries, frozen-context tombstones, version-independent protocol-lifetime seed, capped quotas, ring capacity and placement. 36 assertions.                                                                                                                                                                                                                                                              |
| [`commitment-model.py`](commitment-model.py)               | Byte-exact fixtures for EIP-712 candidates; MessageV1, ingress, ContextV2, Store, Bridge, Pool, accumulator and policy interfaces; forced Queue V11 credits; source/destination domains; Bridge and ten-component infrastructure descriptors; acyclic migration/registration verifier configurations; the five-argument L1 migration activation; release manifests and receipts; LP settlement-bound terminal leaves; bounded session configuration, ABI/events, Router readiness and blobs. 274 golden vectors / 513 assertion sites. |

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
python3 settlement-window-model.py   # 186 assertions
python3 test-settlement-window.py    # 191 adversarial regression tests
python3 lookahead-model.py           # 36 assertions
python3 commitment-model.py          # 274 golden vectors / 513 assertion sites
```

All run standalone; the property models print `ALL PROPERTIES PASS`, and the regression suite
uses `unittest`. The lookahead
model has a pure-Python Ethereum Keccak implementation and uses PyCryptodome only as an optional
speedup. Signatures, validity proofs, EVM gas and execution remain placeholders in the settlement
model. **Every consensus change must update the relevant model in the same commit.** A passing
model is regression evidence, not a proof of protocol soundness.

## Status

The architecture is an **audited design candidate**, not an implementation-ready or
production-ready specification. Its remaining design blocker is the target-Settlement canonical
adoption callback and Router activation guard; after that is frozen, the absent initial executable
execution profile and independently reproduced conformance bundle remain the implementation
boundary. Section 13 states why inventing that implementation-dependent artifact in prose would be
unsafe. Seven later measurable release gates
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
- **Bridge ingress has separate data and liquidity boundaries.** Launch supports DIRECT ETH only
  from the settlement L1 to the slot chain; V1 selectors and Vault flows are untouched. A fresh
  immutable SourceBridge escrows `value + executionFee + liquidityFee`, and the durable V11 Queue
  descriptor pins the complete source/destination context. Any LP may fund a non-transferable L2
  Pool ticket and atomically fund `value + executionFee` for a pinned credit. DONE consumes the
  exact debit and authenticates the LP's L1 pull in the terminal leaf; a rolled-back attempt leaves
  the ticket byte-identical, while FAILED/cancellation refunds the user. Without a willing LP,
  processing is UNFUNDED and later expires—bounded
  economic delivery is not claimed. Missing Message bytes likewise lead to source cancellation
  after `enqueueBy` or destination FAILED after `processBy`. Terminal outcomes use a 64-word
  frontier/root plus canonical events and historical 64-sibling proofs. Destination processing is
  local-domain-bound; source enablement waits for the finalized one-shot L2 registrar proof and 214
  L1 blocks. Cross-L1 kind-1 ingress is not part of this version.

Final acceptance requires a human safety review. The models and the specification are a gate, not
a signature.
