# Slot-Chain — Taiko preconfirmation protocol (v2 design)

This directory holds the design specification for Taiko's v2 preconfirmation protocol, together
with the executable models that verify its consensus-critical arithmetic.

## Contents

| File                                                       | What it is                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| ---------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [`slot-chain-spec.pdf`](slot-chain-spec.pdf)               | **The specification.** A4, single column. This is the artifact to read and circulate.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| [`tex/main.tex`](tex/main.tex)                             | **The source.** Hand-maintained LaTeX; edit this to change the document.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| [`settlement-window-model.py`](settlement-window-model.py) | Unified protocol/state model for finite staged genesis campaigns and proof-first later migration, continuous seat scheduling, forced-queue recovery, same-L1 DIRECT ETH ingress, fresh immutable V2 endpoints, permanent inbox pins, permissionless LP-owned atomic-funding tickets, source user/LP pull conservation, terminal frontier proofs, historical destination retirement, and atomic rollback/reorg behavior.                                                                                                                                                                                                                                                                                                       |
| [`lookahead-model.py`](lookahead-model.py)                 | Exact lookahead path: absolute clock conversion, EIP-4788 carrier/parent semantics, execution-block finality, partial/empty registries, frozen-context tombstones, version-independent protocol-lifetime seed, capped quotas, ring capacity and placement. 38 assertions.                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| [`commitment-model.py`](commitment-model.py)               | Byte-exact fixtures for EIP-712 candidates; MessageV1, ingress, ContextV2, Store, Bridge, Pool, accumulator and policy interfaces; forced Queue V11 credits; source/destination domains; Bridge and ten-component infrastructure descriptors; acyclic migration/registration verifier configurations; the five-argument L1 migration activation; MACT/MFRZ/MCAN/QMIG/MAPS and atomic legacy genesis cutover journals; strict deployed legacy proposal/forced codecs; fixed-key resume-verifier and direct checkpoint-service profiles; release manifests and receipts; LP settlement-bound terminal leaves; bounded session configuration, ABI/events, Router readiness and blobs. 591 golden vectors / 1317 assertion sites. |
| [`seat-market-model.py`](seat-market-model.py)             | Executable custody, fixed-width wire-codec and state model for the four-cell perpetual reverse auction, staging, premium reserves, pull credits, bond terminalization and release rotation. Its companion suite currently runs 102 adversarial tests.                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| [`economic-profile-model.py`](economic-profile-model.py)   | Strict schema and checked-arithmetic validator for the versioned economic profile and every published parameter relation. Its companion suite currently runs 36 tests.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |

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
python3 settlement-window-model.py   # 184 assertions
python3 test-settlement-window.py    # 240 adversarial regression tests
python3 lookahead-model.py           # 38 assertions
python3 commitment-model.py          # 591 golden vectors / 1317 assertion sites
python3 -m unittest test-seat-market.py      # 102 adversarial tests
python3 -m unittest test-economic-profile.py # 36 schema/economic tests
```

All run standalone; the property models print `ALL PROPERTIES PASS`, and the regression suite
uses `unittest`. The lookahead
model has a pure-Python Ethereum Keccak implementation and uses PyCryptodome only as an optional
speedup. Signatures, validity proofs, EVM gas and execution remain placeholders in the settlement
model. **Every consensus change must update the relevant model in the same commit.** A passing
model is regression evidence, not a proof of protocol soundness.

Migration-arm governance keeps the full `PROTOCOL_CHANGE_DELAY_SECONDS=604800` notice and adds a
finite `MIGRATION_ARM_EXECUTION_WINDOW_SECONDS=604800` after maturity. Both the Timelock and PVM
enforce the inclusive execution interval. A successful expiry abort advances the PVM's monotone
`armFreshAfter` watermark, invalidating every arm queued at or before the abort timestamp; a retry
must be queued later and wait a new seven days. `protocolVersionManagerConfigV1()` is therefore
1,088 bytes and commits the execution-window constant, while `migrationArmFreshAfterV1()` returns
the exact 64-byte `MAF1` watermark view. The generic 256-byte `PCO1` operation row is unchanged.

## Status

The architecture is an **audited design candidate**, not implementation-ready or a production-ready
release. The BRS1/BRD1/BRC1/ABR2 route path now derives its authority from fixed-width
RTR2/BRX1/PIR2/PIM2/PIA2/BIP1/BID1 raw reads rather than an in-process
`SettlementRegistration` witness. Production is still blocked by the lack of an address-indexed EVM
component world for Registry code/config/immutable reads, a root receipt deploying the fixed Source
factory and real compiled adapter artifact, and O(1) indexes for the remaining append-only-history
hot paths. Restart and serialization coverage, the complete root-deployment transcript, historical
release/reclamation restart fixtures and measured EIP-150 gas certificates also remain open. ICV2
now supplies the exact O(1) credit-ID and fee lookup; RAV2 binds the Authority retirement watermark;
and DRV2/DSV2 preserve direct-successor, multi-hop reclamation independently of the latest tip. The exact
Settlement--Market roster wire, direct historical economics and Router-authenticated rotation are
now normative fixed-width protocols with strict no-op, rollback, lock and gas rules. The strict
canonical ExecutionProfileV2 ABI, complete field/DAG derivation and negative
legacy-CBOR boundary are now normative and executable. The exact
target-adoption, source-freeze, Queue-migration, poststate-join and legacy-genesis callbacks now
share one Router lifecycle/context journal. A delayed finite genesis campaign stages separate
forced/proposal cutoffs, hard-capped exact scans and a bounded reversible QUIESCENT phase while the
public legacy gate remains ACTIVE. Any caller may land a valid campaign/scan-bound proof through
proof verification, LGAR, LGFN and atomic publication in one transaction; if no proof lands, hard
block/time expiry permissionlessly restores legacy ACTIVE. Safe in-place genesis cutover is conditional on the
deployed legacy Inbox accepting the specified final storage-compatible implementation; otherwise
that deployment requires an independently initialized state migration. In-place cutover snapshots
and imports only the last finalized legacy checkpoint; unfinalized proposals and pending forced
blob records are explicitly abandoned because the deployed format has neither durable bytes nor a
refund owner. A deployment requiring lossless treatment must also use a separate state migration.
The campaign applies 1,024-row proposal/forced caps, a 4 MiB scan cap and
deterministic maximum-progress 16-row scan batches, so a front-run cannot stretch the 128-call bound.
Its byte-exact review envelope binds the live legacy resume profile and target tuple; blob expiry is
derived only from the stored timestamp and the pinned 1,572,864-second mainnet minimum. The sealed
activation receipt binds a separate abandonment hash covering the exact scanned and actually abandoned
ranges, roots, bytes, fees and zero bond liability. Raw donated surplus is excluded from eligibility and
the receipt and remains locked, so forced ETH cannot veto migration or invalidate a prepared proof. A bad target requires campaign expiry
and a higher-nonce delayed review; a total proving-system outage delays migration but cannot
permanently pause a previously live legacy deployment. Legacy deployments whose verifier, bond,
challenge or custody clocks do not match the pinned resume-safe profile must use a separate state
migration. The supported profile requires public proving and an age-independent fixed-key
RISC0+SP1 route; SGX-required roots, mutable trust-map wrappers, a SignalService ForkRouter, or an
unfenced direct checkpoint implementation are rejected before campaign publication. The same is
true when any pending forced or unfinalized proposal row lacks the full data-expiry slack through
hard resume plus 900 seconds for fresh proof generation; stale rows are never ignored merely because
successful migration would abandon them.
The absent initial
executable execution profile, compiled contracts/circuit and independently reproduced conformance
bundle remain the implementation boundary. Section 13 states why inventing those
implementation-dependent artifacts in prose would be unsafe. Eight later measurable release gates
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
