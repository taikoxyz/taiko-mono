# Slot-Chain — Taiko preconfirmation protocol (v3.0 design)

This directory holds the design specification for Taiko's next preconfirmation protocol
("Slot Chain"), together with executable models, a learning deck and a source-backed
implementation status guide. [PR #22139](https://github.com/taikoxyz/taiko-mono/pull/22139)
consolidates the design and a partial Solidity implementation. The protocol is not yet implemented
end to end.

Revision v3.0 reshapes the v2.28 design around three requirements:

1. **It builds on the anchor-free L2 of [issue #22147](https://github.com/taikoxyz/taiko-mono/issues/22147).**
   The L2 header carries the L1 anchor block hash in `parentBeaconBlockRoot`, the standard EIP-4788
   pre-execution call records it on L2, and the permissionless `revealCheckpoint` on the L2
   `SignalService` turns it into a checkpoint. Slot Chain adds no system transaction and no new
   L2 contract; the only L2 rules are header validation and forced-prefix composition.
2. **It uses the existing SignalService, Bridge and vaults on both chains, unchanged.** The L1
   Settlement writes every canonical L2 checkpoint into the L1 SignalService inside the canonical
   commit; the escape lane is the bridge liveness floor in both directions. The v2.28 fresh custody
   design (kind-1 credits, SourceBridge/DestinationBridge bundles, liquidity pool, terminal
   accumulator, release authority, root factory) is removed.
3. **It is an in-place upgrade of the existing L1 Inbox proxy** under the existing DAO governance:
   install, drain every V1 proposal and forced inclusion under V1 rules, then activate by importing
   the last finalized header. Every Slot Chain contract is an ordinary UUPS proxy. The v2.28
   immutable timelock/version-manager/router stack and the legacy genesis campaign are removed.

## Contents

| File | What it is |
| --- | --- |
| [`tex/main.tex`](tex/main.tex) | **The specification (normative source).** Hand-maintained LaTeX; edit this to change the document. |
| [`slot-chain-spec.pdf`](slot-chain-spec.pdf) | **Stale.** The committed PDF is the v2.28 build; the v3.0 revision has not been rebuilt yet (see below). Read `tex/main.tex` until it is. |
| [`slides/slot-chain-learning-deck.html`](slides/slot-chain-learning-deck.html) | **The learning deck.** A browser-based introduction to the v3.0 design; see [opening and printing instructions](slides/README.md). |
| [`implementation-status.md`](implementation-status.md) | Source-backed map of what is implemented, what is specified only, and how to read the conformance evidence. |
| [`settlement-window-model.py`](settlement-window-model.py) | Protocol/state model for activation import, continuous seat scheduling, forced-queue recovery, the kind-0 forced queue, the atomic L1 checkpoint write and rollback/reorg behaviour. Companion suite: `test-settlement-window.py`. |
| [`lookahead-model.py`](lookahead-model.py) | Exact lookahead path: absolute clock conversion, EIP-4788 carrier/parent semantics on L1, execution-block finality, partial/empty registries, frozen-context tombstones, protocol-lifetime seed, capped quotas, ring capacity and placement. |
| [`commitment-model.py`](commitment-model.py) | Byte-exact fixtures for EIP-712 candidates, canonical core and statement hashes, kind-0 forced descriptors and queue roots, fixed-tree and Data MMR proofs, BuilderRegistry witnesses and mutation calldata/returns, proof-verifier configuration, equivocation masks, data sessions and blobs. Generates the golden vectors under `test/shared/slotchain/vectors/`. |
| [`seat-market-model.py`](seat-market-model.py) | Executable custody, fixed-width wire-codec and state model for the four-cell perpetual reverse auction. Companion suite: `test-seat-market.py`. |
| [`economic-profile-model.py`](economic-profile-model.py) | Strict schema and checked-arithmetic validator for the versioned economic profile. Companion suite: `test-economic-profile.py`. |

## Learning the design

Start with the [Slot Chain learning deck](slides/slot-chain-learning-deck.html) for an overview of
builder authority, settlement and recovery, forced transactions, the header-carried anchor,
bridging through the existing contracts, governance and the in-place upgrade from V1. Open the
HTML locally in a browser; its print layout also supports saving a PDF. See the
[deck README](slides/README.md) for instructions and provenance, and the
[implementation status guide](implementation-status.md) for source links and missing components.

The deck is a non-normative companion to the v3.0 specification. That label is the document
revision, not an on-chain protocol version. Use the specification for exact validity rules,
encodings and implementation requirements.

## Building the PDF

`main.tex` is self-contained — the TikZ figures live inline in it, and no generator is involved.

```sh
cd tex && tectonic main.tex
cp main.pdf ../slot-chain-spec.pdf
```

Tectonic automatically performs the passes needed to settle the table of contents and
cross-references. `xelatex`/`pdflatex` also work with repeated passes. The committed
`slot-chain-spec.pdf` must be regenerated from `tex/main.tex` before the v3.0 revision is
circulated; until then it is the v2.28 build and disagrees with the source. Rebuilders must
visually inspect the schedule, state-machine, liveness, slashing and parameter-table pages; a
successful LaTeX exit status alone is not layout verification.

## Running the models

```sh
python3 settlement-window-model.py   # 101 assertions
python3 test-settlement-window.py    # 106 adversarial regression tests
python3 lookahead-model.py           # 38 assertions
python3 commitment-model.py          # 323 golden vectors / 419 assertion sites
python3 commitment-model.py --export-json # 323 sorted typed oracle rows
python3 -m unittest test-seat-market.py      # 115 adversarial tests
python3 -m unittest test-economic-profile.py # 42 schema/economic tests
python3 -m unittest test-forced-transaction-validity.py
python3 -m unittest test-l1-resource-bounds.py
python3 -m unittest test-seat-promotion-economics.py
```

All run standalone; the property models print `ALL PROPERTIES PASS`, and the regression suites
use `unittest`. The lookahead model has a pure-Python Ethereum Keccak implementation and uses
PyCryptodome only as an optional speedup. Signatures, validity proofs, EVM gas and execution remain
placeholders in the settlement model. **Every consensus change must update the relevant model in
the same commit.** A passing model is regression evidence, not a proof of protocol soundness.

The v2.28 bridge/custody, migration-journal, legacy-campaign and root-bootstrap sections of the
models were removed together with the design; `test-migration-journal.py` and
`test-route-preparation-resources.py` no longer exist. The drain phase of the V1 upgrade is V1
behaviour and is covered by the testnet drill gate, not by a model.

## Implementation status

The repository includes the BuilderRegistry and its fixed lifecycle facets and proof verifier,
schedule SSZ multiproof verification and snapshot evaluation, historical L1 header proofs, and
shared codecs, commitments, trees, signatures, evidence, custody-accounting and economic libraries.
Foundry suites, golden vectors and TypeScript checks accompany that code. Settlement (the new
implementation of the existing Inbox proxy), ForcedQueue, ScheduleOracle, AggregatorSeatMarket,
the L2 client fork rules and the circuits remain `missing` in the implementation ledger. The
v2.28 root factory, migration executor, CREATE3 proxy, registration MPT verifier, execution-profile
codec and every bridge/custody library were deleted with the design.

The [conformance ledger](../../utils/slotchain/conformance-ledger.v3.0.json) has 60 rows:
28 `missing`, 25 `red`, 6 `passing` and 1 `reviewed`. Rows include artifacts, external dependencies and roles as well as contracts;
these counts are not a percentage of implementation completion. The checker validates ledger
consistency and reviewed-file hashes while allowing incomplete rows. See
[implementation status and validation commands](implementation-status.md) before interpreting a
successful check as release evidence. The additive code is not selected on a production path.

## Design status and production gates

The v3.0 architecture is a **reviewed design candidate with partial implementation**. Five
properties are worth knowing before reading:

- **Landing is permissionless.** A block's authority comes from its builder's signature, not from
  whoever carries it to L1. The aggregator is a paid service role, not a gatekeeper.
- **There is a builder-independent censorship floor.** A prepaid L1 forced-transaction queue opens
  recovery when its head becomes due. Anyone can prove an unsigned deterministic escape block,
  even if every builder colludes and no aggregator seat exists. The escape block may be empty.
- **One header field replaces the anchor transaction.** Every block's `parentBeaconBlockRoot` is
  the candidate's L1 anchor hash. EIP-4788 records it on L2; anyone reveals it into a permanent
  checkpoint within the 8,191-second window. The L2 EVM is fully standard.
- **Bridging uses the existing contracts.** L1→L2 through the existing Bridge, the header anchor
  and `revealCheckpoint`; L2→L1 through the Settlement's `saveCheckpoint` write on every canonical
  commit. The existing Bridge pause, quota and fee rules apply; Slot Chain adds no
  pause-independent path.
- **Recovery expires unfinalized preconfirmations.** At an objective SLA/force boundary, one
  episode restores finality with the first valid signed or unsigned proof. Progress still requires
  a root-verifiable canonical prestate package containing trie nodes and runtime-bytecode
  preimages.

Production still requires the complete contract set, real circuits and keys, L2 client fork
support (geth/reth header validation), measured proof and activation gas, calibrated economics,
the drain-and-activate drill on a production fork, multi-client testnet soak, independent
conformance reproduction and independent audits. Final acceptance requires a human safety review.
The models and the specification are a gate, not a signature.
