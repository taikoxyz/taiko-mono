# Slot-Chain — Taiko preconfirmation protocol (v2 design)

This directory holds the design specification for Taiko's v2 preconfirmation protocol, together
with the executable models that verify its consensus-critical arithmetic.

## Contents

| File | What it is |
| --- | --- |
| [`slot-chain-spec.pdf`](slot-chain-spec.pdf) | **The specification.** A4, single column, 64 pages, 9 figures. This is the artifact to read and to circulate. |
| [`tex/main.tex`](tex/main.tex) | **The source.** Hand-maintained LaTeX; edit this to change the document. |
| [`settlement-window-model.py`](settlement-window-model.py) | Executable reference model of the settlement window: the total-order key of §5.2, the window state machine of §5.6, cursor arithmetic and gas shares, the timing geometry, the slot-based slashing gate, the first-valid-proof fallback round with coverage pricing, the funding capture rule and recovery bounty, the unified exit-release predicate with snapshot expiry, and the disjointness of the reward escrow from the penalty bond. 65 property assertions (Appendix C). |
| [`lookahead-model.py`](lookahead-model.py) | Executable reference implementation of the lookahead of §3.2: window alignment, snapshot uniqueness, seed derivation and weighted sampling. 6 property assertions. |

## Building the PDF

`main.tex` is self-contained — the TikZ figures live inline in it, and no generator is involved.

```sh
cd tex && xelatex main.tex && xelatex main.tex && xelatex main.tex
```

Three passes are needed to settle the table of contents and cross-references. `pdflatex` works
equally well — the document uses Palatino via `mathpazo` and needs no CJK fonts. The committed
`slot-chain-spec.pdf` is a copy of the resulting `tex/main.pdf`.

The PDF is deliberately emitted as **PDF 1.4** (classic xref table plus a `trailer` dictionary,
no object or cross-reference streams). PDF 1.5 is about 28% smaller, but parsers that implement
only 1.4 — which includes a good deal of e-reader firmware — report such a file as damaged.

## Running the models

```sh
python3 settlement-window-model.py   # 65 assertions
python3 lookahead-model.py           #  6 assertions
```

Both are zero-dependency and print `ALL PROPERTIES PASS` when every assertion holds. They model
only what this design newly introduces — the total-order key, the window state machine, cursor
arithmetic, gas shares, the timing geometry and the fallback reward metering; signatures, proofs and execution are boolean
placeholders. **Any change to the §5.2 total order, the §5.6 window state machine, or the §7
cursor and gas rules must be mirrored in the model, and the model re-run.** A specification whose
model no longer passes is a specification with a defect in it.

## Status

The core mechanism is specified and its modelled arithmetic is internally consistent. It is **not
implementation-ready**: parameter values are initial proposals, and §11 carries open items —
including builder-set admission rules, the proving-outage exemption (blocking), L1 reorg handling,
genesis and bootstrap semantics, the cost of the separated data path, the indexing procedure behind
`C_fixed`, and the proof continuation that several liveness arguments depend on. Three properties
of the design are worth knowing before reading:

- **Landing is permissionless.** A block's authority comes from its builder's signature, not from
  whoever carries it to L1. The aggregator is a paid service role, not a gatekeeper.
- **There is no censorship-resistance floor.** Forced inclusion was removed deliberately, for
  simplicity. If every scheduled builder refuses a transaction, the protocol offers no remedy and
  no builder-independent exit. §8's cartel rows are unbounded, and §1 records this as a withdrawn
  goal rather than an oversight.
- **Fallback expires unfinalized preconfirmations.** When an aggregator fails, the protocol abandons tier-2 ordering and state promises and restores finality with the first valid chain meeting a progress target. A preconfirmation held during a failure carries no ordering or state guarantee — only that the transaction stays includable. This is an explicit owner decision and the price of a fallback that cannot be griefed.
- **A builder's signature does not attest that the block executes.** It attests authorship and the
  choice of parent. Executability is established only by the validity proof at landing, so a
  preconfirmation is a commitment to include and to order (§9).

Final acceptance requires a human safety review. The models and the specification are a gate, not
a signature.
