# Phase B - the public-data programme

**Why this document exists.** Phase B was specified as hardware measurement (see [README.md](./README.md)
and S1-S5). No hardware and no testnet are available. This is the substitution: the same questions
answered, where they can be, from **existing Taiko transactions on Ethereum mainnet**, Taiko's own RPC,
and **reputable third-party published measurements**.

A substitution is only honest if it says what it cannot do. So this document has two halves: what public
data establishes, and what it does not - with the second half stated as plainly as the first, and no
empty cell filled with an estimate.

## The status ladder - every figure carries exactly one label

| Label | Means | May be used to |
|---|---|---|
| **[on-chain measured]** | read from a transaction, block, event or storage slot on a named network over a named block range, reproducible from a stated command | fix or bound a parameter, if the measurement covers the rule's scope |
| **[third-party reported]** | published by someone else, with a named source and methodology | bound a parameter, or set a provisional value that stays tagged |
| **[bounded]** | derived from an on-chain or published fact under stated assumptions | bound only - the bound and its assumptions travel with the number |
| **[not establishable]** | public data cannot answer it | nothing. It stays a tagged placeholder |

**Rule: a lower label may never be presented as a higher one.** A third-party proving benchmark is not a
measurement of this design's guest; a live-network cadence is not a per-machine capability; a design
target is not a result. The specification's own discipline already requires this - every unmeasured
parameter is tagged - and Phase B does not get to relax it because it is inconvenient.

## Compound and qualified labels

Some figures rest on more than one kind of evidence, or on a scope smaller than the whole network. The
reports write those as a compound or qualified label. That is a bookkeeping device for *what the figure
rests on*, not a fifth rung, and it is **capped at its weaker half**: a compound never gains strength
from the stronger of its parts.

| Form | Means | May be used to |
|---|---|---|
| `[label A] / [label B]` | the figure rests on both A and B (e.g. `[on-chain measured] / [derived]`: a measured input and arithmetic over it) | whatever the **weaker** of A and B allows |
| `[label, scope]` | the label with a scope qualifier (e.g. `[on-chain measured, third-party network]`, `[on-chain measured, small sample]`, `[on-chain measured, bounded]`, `[derived; inputs on-chain measured]`) | whatever the label allows **within the stated scope** |
| `[third-party reported - source/methodology]` | the label with its source annotation after a dash | as `[third-party reported]` |

Two recurring labels are defined here because they are not literally on the ladder. **`[first-party
published]`** = published by Taiko itself, not independently measured in this programme; it is treated as
`[third-party reported]` (it may bound a parameter or set a provisional, tagged value - never fix one).
**`[sourced - vendor documentation]`** = a vendor's own documentation; also `[third-party reported]`.
`[derived]` is not a separate rung: it is shorthand for `[bounded]` when the arithmetic and its
measured inputs are shown, and is read at that strength.

So the operational question - may this figure fix a parameter? - is still answered by the four-rung table
above, read at the weakest component of the label.

*(Added by review finding PB-L-05: the ladder said "exactly one label" while the reports used compound
and off-ladder forms; the forms are now defined and capped, and the one `[derived]` row in the synthesis
is relabelled `[bounded]`.)*

## What each spike becomes

| Spike | From hardware measurement | To public data | What stays open |
|---|---|---|---|
| **S1** proving throughput | cycles and bytes per L2 gas, proven gas/s per machine | **on-chain proof cadence** (achieved throughput, a lower bound) + **third-party zkVM benchmarks** | per-machine throughput at a stated hardware spec; cycles per L2 gas for this design's guest; the DA-limited vs proving-limited verdict |
| **S2** round timing at n=50-200 | round completion with faults, at validator counts | **the timing budget**: L1 block-time distribution and tail, live Taiko cadence, published BFT round-latency data | whether D1's 2 s cadence holds at the intended n - that is a design target and needs machines |
| **S3** L1 cost and fee flow | `land` gas at a fixed workload, K ∈ {8,32,128} | **the real cost curve**: every Taiko batch-landing transaction over a stated window, decomposed into execution gas, data cost and overhead, against both blob and normal base fee - **fully measurable** | cost at a K this network has not run; proving cost, which S1 can only bound |
| **S4** blob binding | binding checks plus cryptographic review | **what Taiko actually does on L1**: DA mode over time, blob counts, blob base fee, versioned-hash checks, and EIP-4844's parameters in force - **mostly measurable** | the **independent cryptographic review** of the binding between published bytes and the proven range. No amount of on-chain data substitutes for it |

## The discipline this programme keeps

1. **Reproducibility.** Every figure ships with the exact command or URL that produced it, the network,
   the block range and the date, and the raw response saved next to the report - so a reader re-runs it
   rather than trusting it.
2. **No substitution without disclosure.** Where a public figure stands in for a hardware measurement, the
   report says so at the point of use, not in a footnote.
3. **No placeholder becomes a guess.** A parameter stays tagged until a measurement of the right kind
   exists. A number that is merely plausible is worse than a tag, because a tag invites the measurement
   and a number discourages it.
4. **The gate is not moved.** Phase B's exit criteria stand as written. This programme can *satisfy* some
   of them from public data, *bound* others, and must **report the remainder as unmet** - it cannot
   declare Phase B complete.

## Reports

Each collector writes one report and its raw evidence under [`results/`](./results/):
`results/<spike>.md` and `results/raw/<spike>/`. Reports state, per finding, the figure, its status
label, the command or URL, the coverage window, and which specification parameter or rule it bears on -
and whether it is sufficient to **fix** that parameter or only to **bound** it.

## What this programme is for

Increment 3 (aggregation) is gated on S1 and the rotation on an L1-verifiable `h_close`; both are parked
because they need a number or a fact that does not exist yet. This programme will not fully unblock
either. What it can do is replace the placeholders that *are* answerable from the chain -
overwhelmingly the S3 cost curve and the S4 DA facts - with measured values, and reduce the rest to
**precise, named, unmeasured quantities**: not 'we do not know the throughput' but 'we know the live
network achieves X, and the unknown is per-machine throughput at hardware Y, which needs measurement Z'.