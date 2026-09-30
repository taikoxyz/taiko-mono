# Etna red team, round 1: goal STEAL FUNDS

- Model: claude-opus-5-5 (Opus 5.5), the requested opus model.
- Goal: finalize a false root, drain bridge or vaults, steal or unlock bonds early, collect slashing payouts or lander/attester rewards without doing the work, or make honest parties lose bonds.
- Prior findings: none (first round).

## Method

1. Read every design page in full (index, roles, sequencing, preconf, landing, slashing, forced-inclusion, bridge-migration, interfaces, parameters, arguments, l1-dependencies, frame-transactions, limitations, glossary). I converted the HTML to text to quote it verbatim. I also read 01-threat-model.md (TH1-TH25, W1-W7, T1-T13, §8 out of scope), README.md (R1-R7, A1-A8) and the verifier and prover sections of 00-current-protocol-summary.md.
2. Listed every rule that moves TAIKO or ETH: lander ramp, attester reward, lander bonus, challenger share, S1-S8, MISS, FI fees and demand fees. For each rule I wrote down its trigger predicate and asked two questions. Can a party that did not do the work satisfy the trigger? Can an honest party be made to satisfy an accusation predicate without deviating?
3. Checked each predicate against the inputs that set it. The question was which of those inputs a third party chooses, for example the landing's anchor tip, the end-certificate bitmap, the range split, or which certificate is submitted as evidence.
4. Kept only traces that stay inside T11 (fewer than Q = 22 colluders per committee), T1 and T3. I added the cost and gain at the design's own inputs: 1 TAIKO = 1.5·10⁻⁴ ETH, V_term = 0.01 ETH, B_SEAT = 20,000 TAIKO.

Notation: E = termEnd(t) as an L1 timestamp. H0 = the height of term t's first block. All times are L1 seconds.

---

## S1. Any landing stall of 30 minutes or