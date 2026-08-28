# Slot-Chain — Taiko preconfirmation protocol (v2 design)

This directory holds the design specification for Taiko's v2 preconfirmation protocol, together
with the executable models that verify its consensus-critical arithmetic.

## Contents

| File | What it is |
| --- | --- |
| [`slot-chain-spec.pdf`](slot-chain-spec.pdf) | **The specification.** A4, single column. This is the artifact to read and circulate. |
| [`tex/main.tex`](tex/main.tex) | **The source.** Hand-maintained LaTeX; edit this to change the document. |
| [`settlement-window-model.py`](settlement-window-model.py) | Unified executable model of normal settlement and fallback: close-before-activate ordering, objective seat turnover, episode binding, split payouts, canonicalization depth, per-window slashing, expiry and replay. 24 assertions. |
| [`lookahead-model.py`](lookahead-model.py) | Exact production lookahead path: integer capped quotas, explicit vacant slots and feasibility-preserving seeded placement. 187 assertions across adversarial registries and seeds. |

## Building the PDF

`main.tex` is self-contained — the TikZ figures live inline in it, and no generator is involved.

```sh
cd tex && xelatex main.tex && xelatex main.tex && xelatex main.tex
```

Three passes are needed to settle the table of contents and cross-references. `pdflatex` works
equally well — the document uses Palatino via `mathpazo` and needs no CJK fonts. The committed
`slot-chain-spec.pdf` is a copy of the resulting `tex/main.pdf`.

The committed artifact is built with Tectonic/xdvipdfmx and currently uses PDF 1.5. Rebuilders
must visually inspect the schedule, state-machine, liveness, slashing and parameter-table pages;
a successful LaTeX exit status alone is not layout verification.

## Running the models

```sh
python3 settlement-window-model.py   # 24 assertions
python3 lookahead-model.py           # 187 assertions
```

Both are zero-dependency and print `ALL PROPERTIES PASS` when every assertion holds. They model
only what this design newly introduces — the scheduling and mode algorithms, cursor arithmetic,
gas shares, expiry, slashing and fallback accounting; signatures, proofs and execution are boolean
placeholders. **Any change to the §5.2 total order, the §5.6 window state machine, or the §7
cursor and gas rules must be mirrored in the model, and the model re-run.** A specification whose
model no longer passes is a specification with a defect in it.

## Status

The core mechanism is specified and its modelled arithmetic is internally consistent. It is **not
yet implementation-ready**: §11 still requires proof/gas benchmarks, complete L1-reorg semantics,
genesis/migration rules and a decision on the strong-permissionlessness boundary. Four properties
of the design are worth knowing before reading:

- **Landing is permissionless.** A block's authority comes from its builder's signature, not from
  whoever carries it to L1. The aggregator is a paid service role, not a gatekeeper.
- **There is no censorship-resistance floor.** Forced inclusion was removed deliberately, for
  simplicity. If every scheduled builder refuses a transaction, the protocol offers no remedy and
  no builder-independent exit. §8's cartel rows are unbounded, and §1 records this as a withdrawn
  goal rather than an oversight.
- **Fallback expires unfinalized preconfirmations.** At the objective SLA boundary the incumbent is terminated, and one persistent episode restores finality with the first qualifying version-bound chain. Omitted tier-2 promises expire.
- **A builder's signature does not attest that the block executes.** It attests authorship and the
  choice of parent. Executability is established only by the validity proof at landing, so a
  preconfirmation is a commitment to include and to order (§9).

Final acceptance requires a human safety review. The models and the specification are a gate, not
a signature.
