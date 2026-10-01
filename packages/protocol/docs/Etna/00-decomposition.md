# Decomposition: what the candidates share, where they differ, who owns what

Written by the arbiter (agent A, Claude) on 2026-10-01 from both trees at their heads of that day (A: `claude/beautiful-maxwell-8pyecj`; B: `codex/etna-protocol-design` at d1732e2 and later) and from the three reviews of that day. The owner of a section writes it; the reviewer (the other author) reviews it adversarially; agent J (DeepSeek) reviews every section as the third voice and judges what is contested. The assignment follows which candidate holds the stronger verified text for that section, not which agent is the arbiter. Any agent may propose a different assignment in the first cycle; the arbiter records the outcome in `DECISIONS.md`.

## 1. The shared core (cycle 1)

After the cross-adoptions of 2026-10-01 the two candidates agree on the following. Each row names the state in each candidate so that the owner starts from the stronger text and the reviewer knows what the other side verified.

| § | Section | Candidate A | Candidate B | Owner / reviewer |
|---|---|---|---|---|
| C1 | **L2 blocks without an anchor transaction.** Standard EIP-4788 and EIP-2935 on L2; the anchored L1 block hash in `parentBeaconBlockRoot`; `extraData` layout; the L2 SignalService's permissionless `revealCheckpoint` with parser bounds; permanent origin pins; the current-root guard that gates the legacy writers; fork-time safety and rollback; the L2 fork order. | Adopted after round 6 from taikoxyz/taiko-mono#22147; the guard, the pins and the parser bounds adopted from B; verified by two independent verifiers; in the design pages from the next commit of A. | Designed, committed and re-reviewed in B's rounds 07 and 08. | **B owns, A reviews.** |
| C2 | **Landing: propose-with-proof.** One L1 action carrying data and proof; the proof-system set (two distinct ZK leaves of N, TEE never counts); the canonical blob encoding and the journal; the checkpoint write; what the inbox checks and what the guest proves; degraded mode (one leaf after an outage, provisional finality with a conflict rule). | The landing page (sections 1 to 12), with the provisional-finality rule after B's review. | Atomic landing with a Dutch rent and proof race; codec and encoding vectors with reproduced digests. | **A owns, B reviews** and contributes the encoding vectors as the test-vector appendix. |
| C3 | **Forced inclusion.** The queue, due-ness at the anchored L1 time, bounds per landing and per request, the stall rule that voids unprovable entries without the DAO, pricing against poison streams, refunds pulled per entry. | 64 entries per landing, blob or 4 KiB calldata requests, void-by-stall with a decaying escalation (round 6 and its fix passes). | 2,048-byte, 1 M-gas requests, four per segment, FIFO (46 h behind a 1,000 backlog by its own bound). | **A owns, B reviews.** The bounds are re-derived under the merged sequencing layer. |
| C4 | **Migration from Shasta.** The freeze and drain, abandonment of the unproven tail with its forced inclusions requeued, the shared-contract upgrades that remove pause and owner-only operational powers with a selector audit, rollback, the first Etna term. | The Anchor page sections M1 to M6 with the requeue rule after B's review; A10. | The migration page: in-place upgrades of every retained proxy, operational powers removed, legacy slots frozen, a proof-backed drain. | **B owns, A reviews.** The requeue rule and the 24-h deadline versus the proof-backed drain are the first decision-log entries of this section. |
| C5 | **L1 dependencies and Frame Transactions.** What Etna needs from Glamsterdam and Hegotá, the EIP-8141 gate for zero-cost landing races, its pins and its stale-nonce cost, and the degradation if it slips. | The roadmap survey, the Frame Transactions research record with its verification note and erratum, the frame-transactions and l1-dependencies pages. | The roadmap pages and the staging gate. | **A owns, B reviews.** |
| C6 | **Threat model, invariants, parameters, assurance.** The asset and actor model, the invariants with their arguments, one parameter table with derivations, the dashboard of what is proven, assumed, open and unmeasured. | Threats TH1 to TH25, invariants I1 to I5, the parameters page. | The assurance dashboard and the evidence-specific confirmation reporting. | **Joint:** A owns the threat model and invariants, B owns the dashboard format and the unmeasured-numbers list; each reviews the other's half. |

## 2. The sequencing layer (cycle 2)

Decision D1 (a slashable, user-actionable confirmation is a requirement) selects the committee design as the sequencing layer; candidate B's open staging and proof race do not provide that confirmation and say so. What remains of B in this layer is reviewed in, not designed out: its advisory landing-intent discovery, its evidence-specific confirmation reporting, and its objections to A's economics.

| § | Section | Starting text | Owner / reviewer |
|---|---|---|---|
| S1 | **Seats, registry, sortition.** Bonded seats, the persistent domain tree, the committee walk, caps, exits, suspensions, key rotation. | A's sequencing page. | **A owns, B reviews**, with the walk gas and the registration gas listed as unmeasured. |
| S2 | **Terms, certificates, locks, handoff.** Terms and views, the attester committee, certificates, lock votes, timeouts, the pipelined handoff, view changes and replacement, the confirmation levels with their exceptions. | A's preconf page after the 2026-10-01 revision. | **A owns, B reviews.** B's review points on labels and availability are the first entries. |
| S3 | **Slashing and economics.** Objective slashing conditions and evidence, rewards, the landing reserve, anti-monopoly measures, the revenue model on unmeasured inputs. | A's slashing and roles pages. | **A owns, B reviews.** The economics are stated as formulas on inputs marked unmeasured (D2); B's cost arithmetic is the template for how figures are presented. |
| S4 | **Roles and liveness arguments.** Every role's entry, exit, duties, rewards, slashing and the all-offline and all-malicious answers; the liveness and safety arguments against R1 to R7. | A's roles and arguments pages. | **A owns, B reviews.** |

## 3. Requirements the merged specification is measured against

R1 to R7 of the brief, unchanged (100 % permissionless with DAO upgrades only; the existing SignalService, Bridge and Vault addresses reused; richer roles; 1-s L2 blocks; no lookahead and no slot coupling; objective slashing with anti-monopoly measures; propose-with-proof in one L1 action with explicit data availability), plus D1 and D2 above. The merged tree restates the table and marks each row pass or fail per section.

## 4. What is explicitly dropped and why

- **The Dutch admission rent and the one-blob staging segment of candidate B.** Its own numbers (about 2 KB/s at about 67 ETH per day, about 137 B/s rent-free) have no viable operating point, as both agents and the comparison agreed.
- **Bonded fragment publication at L1 calldata prices.** About 64 gas per byte makes every published byte cost what calldata costs; the merged design keeps availability through the committee's execution requirement and the retention duty, and records the residual (a failure to serve is unprovable on L1) as a limitation.
- **Pause and owner-only operational powers on the shared contracts.** Removed by compatible upgrades (D1 of candidate B's migration, adopted by A as A10).
- **The anchor transaction.** Both candidates adopted taikoxyz/taiko-mono#22147.

## 5. What agent J reviews first

Before cycle 1 starts, J checks this decomposition against both trees: whether any shared mechanism is missing from section 1, whether any row's "stronger text" claim is wrong, and whether the dropped items in section 4 are dropped for reasons the trees support. J's findings open the first decision-log entries.

## 6. Cycle 0 deliverables

This file, the charter (`README.md`) and the decision log. The next commits add `spec/` skeletons with the section headings and the owner's name in each, so that every section's first pull request edits an existing file.
