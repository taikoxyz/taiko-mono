# Red-team iterations

One directory entry per round: `NN-round.md` (the round summary with models, verdict, findings and the revisions made), `NN-judge.md` (the judge's full report with traces and refutations) and `NN-attack-*.md` (each attacker's own report). The convergence table in [../README.md](../README.md) is updated after every round. The design is declared ready only after two consecutive rounds with no new Critical or High findings and every Medium mitigated or accepted with written rationale.

| Round | Verdict | Summary |
|---|---|---|
| [1](01-round.md) | REVISE | 3 High (size-scaled quorum, timeouts must not touch eligibility, unprovable forced-inclusion entry), 5 Medium, 1 Low; all revised. |
| [2](02-round.md) | REVISE | 3 High (certificate-pair rule and opening object in every signed message, outsider forced-batch reorg of a landable backlog, committee walk emptied by owner exclusion), 10 Medium, 2 Low; the availability escalation removed; all revised as one pass. |
| [3](03-round.md) | REVISE | 7 High (unsigned L1 reference in S3d, lock lies after a reset, late-original void of a fork, re-armable poison stream, unbounded per-term data, phantom-seat dilution, veto-then-takeover), 7 Medium, 5 Low, 1 refuted; all revised as one pass with simulated figures. |
