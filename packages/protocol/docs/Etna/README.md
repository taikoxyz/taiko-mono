# Etna, converged specification

> **Status: research in progress, converging two candidate designs into one specification. Not an implementation, not a description of any deployed system, and not ready.**

This branch (`etna/converged-spec`) is the shared workspace in which the two candidate designs for Etna, the fully permissionless successor to Taiko's based-rollup protocol, are merged into one specification:

- candidate A: [PR #22184](https://github.com/taikoxyz/taiko-mono/pull/22184), branch `claude/beautiful-maxwell-8pyecj` (the committee design: bonded seats, sortition, BLS committees, certificates with slashable "locked" confirmations, propose-with-proof landing);
- candidate B: [PR #22188](https://github.com/taikoxyz/taiko-mono/pull/22188), branch `codex/etna-protocol-design` (the "Astra" design: open staging, proof-race landing with a Dutch rent, soft local blocks, a reviewed migration that strips operational powers).

Both candidates were reviewed by the other's agent and by an independent comparison on 2026-10-01 ([comment](https://github.com/taikoxyz/taiko-mono/pull/22184#issuecomment-5926626192)). Three agents take part in the convergence, each directed by the user: **A** (Claude, the agent of candidate A and the arbiter), **B** (Codex, the agent of candidate B) and **J** (DeepSeek, the author of the independent comparison, the independent reviewer and judge). After the cross-adoptions of that day, the two share most of the plumbing and differ on the sequencing layer and its economics. The decomposition in [`00-decomposition.md`](00-decomposition.md) says which parts converge first and who owns each section.

## Decisions by the owner of the work (the user), 2026-10-01

| # | Question | Decision |
|---|---|---|
| D1 | Is a slashable, user-actionable confirmation (about two seconds after a transaction is sent, backed by provably slashable stake) a requirement of the final proposal? | **Yes.** It is a requirement. The sequencing layer must provide it. |
| D2 | Is implementation in scope? | **No.** The target is a specification ready to be implemented later (not soon): complete and internally consistent at the level of interfaces, parameters, encodings and migration, with every unmeasured number marked as such. |
| D3 | Who arbitrates disputes between the agents? | **Agent A** (the maintainer of this branch). Product and scope questions go to the user. Because the arbiter is a party to the dispute, every contested technical decision is recorded in [`DECISIONS.md`](DECISIONS.md) with both arguments and the verdict of agent J, the independent judge, so the user can see where the arbiter overruled the other side. |
| D4 | Where does the merged work live? | **This branch**, with one tree under `packages/protocol/docs/Etna/`, superseding both candidate trees when it is done. |
| D7 | Which agents take part? | **Three:** A (Claude, candidate A, arbiter), B (Codex, candidate B), J (DeepSeek, independent reviewer and judge). |

## Working agreement between the three agents

1. **Channel.** GitHub only: pull requests against this branch, their review threads, and this tree. A shared agent channel was declined by the agents for security reasons. The user relays the brief to each agent and posts on its behalf where the agent has no GitHub access of its own.
2. **Sections and ownership.** `00-decomposition.md` lists every section with an owner (A or B) and a reviewer (the other author). The owner writes the section as a pull request against `etna/converged-spec`; the reviewer reviews it with an explicit verdict (approve, or request changes with the exact sentence and the reason); J reviews every section as a third voice, non-blocking except for a Critical or High finding, which blocks like the reviewer's; nothing is accepted on the owner's say-so, and nothing is merged without the reviewer's verdict or, failing one within a cycle, the arbiter's recorded decision.
3. **Normative text.** Every rule is stated once, on the page that owns it, with the adversary schedule it covers. Every claim is tagged **proven** (argued on the page; nothing is machine-checked), **assumed** (a premise or a cited source) or **open**. Every number carries its derivation or is marked unmeasured. Plain prose, no em-dashes.
4. **Disagreements.** A disagreement that survives one exchange becomes an entry in `DECISIONS.md`: the question, both positions with their arguments, J's verdict as the independent judge, the arbiter's decision and the user's sign-off where the question is product or scope. Decisions are reversible by a later entry, never by silent edits.
5. **Convergence criterion.** The merged specification is called converged only when two consecutive red-team rounds (three attack goals on three different models plus a judge, the same loop both candidates used) find no new Critical or High finding against it, every Medium is mitigated or accepted in writing, and the readiness checklist below is complete. A and B run the attack goals in alternation; J judges each round and audits the readiness checklist; the arbiter records every round in `iterations/`.
6. **Readiness checklist (spec-level, D2).** Complete interface definitions (functions, events, errors, storage layouts, upgrade paths), parameters with derivations, encodings with test vectors, the migration runbook, the threat model with every invariant and its argument, the list of unmeasured numbers an implementation must measure first, and the open questions the owners accept.
7. **Cycles.** Cycle 0: charter, decomposition, section skeletons (this commit). Cycle 1: the shared core (sections C1 to C6). Cycle 2: the sequencing layer and its economics under D1 (sections S1 to S4). Cycle 3 and later: joint red-team rounds until the criterion holds, then the readiness checklist.
8. **Credit.** Every adopted mechanism keeps a citation to the candidate and the review that produced it.
9. **What J does not do.** J neither owns nor writes a section; its findings are verified by the owner like any review finding, and its verdicts in the decision log are recorded, not binding (D6).

## Layout of this tree

| Path | Content |
|---|---|
| [`00-decomposition.md`](00-decomposition.md) | What the two candidates share, where they differ, section list with owners and reviewers |
| [`DECISIONS.md`](DECISIONS.md) | The decision log |
| [`WORK.md`](WORK.md) | The work orders: who does what next, assigned by agent A (D11) |
| `spec/` | The merged specification, one file per section (cycle 1 onward) |
| `iterations/` | Red-team rounds against the merged specification (cycle 3 onward) |

The candidate trees stay on their own branches as the record of how each design was reached; this tree cites them rather than copying their history.

## Section drafts

| Section | Owner / reviewer | Status |
|---|---|---|
| [C1: anchor-free L2 execution and checkpoint publication](spec/C1-anchor-free-l2.md) | B / A; J independent review | **Merged** under D28; proposed rules, interfaces, adversary schedules and numeric register; A/J review and cross-section integration pending. |
| [C2: landing](spec/C2-landing.md) | A / B; J independent review | **Merged** under D36 (approved by B at `fb6180a`); owner gates listed in D36. |
| [C4: migration and retained surfaces](spec/C4-migration.md) | B / A; J independent review | **Merged** under D27 (approved by A at `93d9038`); gates owned by C2, C3, S2 and C8 stay open as C4 states them. |
| [C5: L1 dependencies and Frame Transactions](spec/C5-l1-dependencies-and-frames.md) | A / B; J independent review | **Merged** under D31 (approved by B at `66e3737`). |
| [C6-B: assurance dashboard](spec/C6-assurance-dashboard.md) and [unmeasured-numbers register](spec/C6-unmeasured-register.md) | B / A; J independent review | **Merged** under D35 (approved by A at `c1ff472`); an index only, re-pinned on each owning-section merge. |

The C1 integration dashboard identifies its dependencies on C2/C3/C4/C6/C7/C8/S2/S3. The merged learning site will follow accepted section text; no legacy candidate course is relabeled as the converged specification. The current draft does not establish D1 or implementation readiness on its own.
