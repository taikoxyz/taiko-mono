# D-12 coordination decisions (lead, 2026-10-06)

Answers to the D-12 agent's questions, recorded so the follow-up pass can act on them.

## 1. PRF-04(vi) is the enforcement point — reserved

The empty slot `PRF-04(vi)` was the forced-inclusion guest check before D-6 deleted it, and its
lettering was deliberately preserved. **D-12's proof-side obligation goes there.** That is a
`spec/05-proof-statement.html` change (PRF-04(vi) text plus a PRF-02 journal field for the
L1-derived forced-data boundary), which the D-12 agent does not own. It is queued as a
follow-up pass on page 05, together with the two amendments another repair already owes that
page (`PRF-04(v)` must take REC-04's single checkpoint link and require no header below
`firstHeight`; `PRF-05(ii)` must add REC-04(3)'s recovery-anchor branch for an epoch-opening
restart and keep zero/zero for a mid-epoch restart). **One agent, one pass, all three** — they
are the same file and the same region.

## 2. The D-11 publication record IS the forced-data record

One register, not two: the permissionless publication record that D-11 introduces is the same
object D-12 anchors to. **No "forced" flag**, no second register. D-12's rules add only:
forceable-from-publication, the due point, FIFO order, the capped per-batch obligation, the
recovery-survival clause, and the enforcement in PRF-04(vi). If the D-11 agent's text defines
the record for proof bookkeeping only, its rule must be broadened rather than duplicated.

## 3. Journal row assignment

`L1-05` rows 1–33 exist; **row 20 is vacant and must not be reused**. D-11's publication and
proving-deadline values take rows **34+**. D-12 **reuses D-11's rows** for the publication
identity and adds at most one row of its own for the due-point boundary, taking the next free
row. Every added row must also appear in §2.1 and in the reverse list, and a journal field
without a row is a protocol defect (that is the rule the section already states).

## 4. Cross-referencing, not restating

D-12's rules cross-reference the D-11 publication record and proving deadline rather than
restating them; `L1-01`/`L1-02`/`L1-03`/`DA-05` wording is the D-11 agent's while it holds
those files.

## 5. Pages still asserting that forced inclusion is absent from v1

D-12 supersedes D-6 and D-10, so every one of these must be reconciled in a final sweep:
`spec/index.html` (FI-REMOVED-01 / FI-PLANNED-01 rows), `spec/01-system-model.html`,
`spec/10-assurance.html` LIVE-04, `01-requirements-and-threat-model.md` and `README.md` (the R10
rows), `04-architecture-decision.md`, `learn/09-censorship-and-the-bridge.html`,
`iterations/03-round.md`, and `spec/06-recovery-exceptions.html`'s "D5 is unchanged" note
(stale under D-11).
