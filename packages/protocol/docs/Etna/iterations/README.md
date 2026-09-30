# Red-team iterations

One directory entry per round: `NN-round.md` (the round summary with models, verdict, findings and the revisions made), `NN-judge.md` (the judge's full report with traces and refutations) and `NN-attack-*.md` (each attacker's own report). The convergence table in [../README.md](../README.md) is updated after every round. The design is declared ready only after two consecutive rounds with no new Critical or High findings and every Medium mitigated or accepted with written rationale.

| Round | Verdict | Summary |
|---|---|---|
| [1](01-round.md) | REVISE | 3 High (size-scaled quorum, timeouts must not touch eligibility, unprovable forced-inclusion entry), 5 Medium, 1 Low; all revised. |
