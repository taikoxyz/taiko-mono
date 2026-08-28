# Slot-Chain — Taiko preconfirmation protocol (v2 design)

This directory holds the design specification for Taiko's v2 preconfirmation protocol, together
with the executable models that verify its consensus-critical arithmetic.

## Contents

| File | What it is |
| --- | --- |
| [`slot-chain-spec.pdf`](slot-chain-spec.pdf) | **The specification.** A4, single column. This is the artifact to read and circulate. |
| [`tex/main.tex`](tex/main.tex) | **The source.** Hand-maintained LaTeX; edit this to change the document. |
| [`settlement-window-model.py`](settlement-window-model.py) | Unified executable mode machine: PREACTIVE/migration, force-due ordering, renewable recovery rounds, triple-bounded prefixes, one anchor, sealed data sessions and replay. 55 assertions. |
| [`lookahead-model.py`](lookahead-model.py) | Exact lookahead path: EIP-4788 carrier/parent semantics, immutable seal deadlines, tombstone overlay, capped quotas, vacant slots and seeded placement. 30 assertions. |
| [`commitment-model.py`](commitment-model.py) | Byte-exact Ethereum Keccak fixtures for EIP-712, registry/tranche/queue/session/recovery/body commitments, blob codec and KZG input. 12 vectors/properties. |

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
python3 settlement-window-model.py   # 55 assertions
python3 lookahead-model.py           # 30 assertions
python3 commitment-model.py          # 12 vectors/properties
```

All run standalone and print `ALL PROPERTIES PASS` when every assertion holds. The lookahead
model has a pure-Python Ethereum Keccak implementation and uses PyCryptodome only as an optional
speedup. Signatures, validity proofs, EVM gas and execution remain placeholders in the settlement
model. **Every consensus change must update the relevant model in the same commit.** A passing
model is regression evidence, not a proof of protocol soundness.

## Status

The consensus mechanism is **implementation-ready as a specification**, but is not yet authorized
for production deployment. Section 13 fixes seven measurable release gates: proof performance,
contract gas, cryptographic conformance, state-machine verification, economics, operations and
external review. Four properties are worth knowing before reading:

- **Landing is permissionless.** A block's authority comes from its builder's signature, not from
  whoever carries it to L1. The aggregator is a paid service role, not a gatekeeper.
- **There is a builder-independent censorship floor.** A prepaid L1 forced-message queue opens
  recovery when its head becomes due. Anyone can prove an unsigned deterministic escape block,
  even if every builder colludes and no aggregator seat exists.
- **Recovery expires unfinalized preconfirmations.** At an objective SLA/force boundary, one
  episode restores finality with the first valid signed or unsigned proof. Its deterministic
  round can be renewed only after objective expiry, so a long prover outage cannot permanently
  stale the recovery target. Omitted promises expire.
- **A builder's signature does not attest that the block executes.** It attests authorship and the
  choice of parent. Executability is established only by the validity proof at landing, so a
  preconfirmation is a commitment to include and to order (§9).

Final acceptance requires a human safety review. The models and the specification are a gate, not
a signature.
