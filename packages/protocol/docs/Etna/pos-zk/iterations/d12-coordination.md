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

## Naming authority and required reconciliation (D-11/D-12/D-13 parallel pass)

Three agents edited pages 02/04/05 and 06/07/08/09/index concurrently with no shared channel, so
names and rule ids may disagree. **`PARAM-01` in `spec/09-parameters.html` is the naming
authority.** The canonical spellings are:

- Publication and deadline: `T_PROVE_DEADLINE`, `PUB_RECORD_RETENTION`, `FI_ITEM_MAX_BYTES`
- Per-batch forced-inclusion cap: `FI_MAX_PER_BATCH` (the `FI_PREFIX_CAP` spelling is withdrawn)
- Proof policy: `K_SETTLE_BACKENDS` (= 1, decided), `K_PROOF_BACKENDS`, `N_PROOF_BACKENDS`,
  `M_AGG_MAX`, `AGG_PROVER_PPM`, `T_AGG_ROTATE_MAX`
- Liveness: `T_INACTIVE`, `D_LAPSE_MAX`, `N_MAX`, `T_ROTATE`, `T_ROTATE_DELAY`, `lastObserved(v)`
- Timing objects that are **not** aliases: `WITHDRAWAL_DELAY` (MSG-03) and `D_WITHDRAW` (MEM-05) are
  distinct; `DRAIN_DEADLINE` is migration-only.

**Obligation:** pages 04 and 05 must use these spellings, and where they do not, a
**name-alignment pass** renames in the rules rather than in the register — the register is the
authority, not the prose.

**Publication record fields** must be aligned with MIG-02's Inbox budget: a `bytes32`
content-derived `publicationId` map, an append-only order map, one packed clock
(`nextSeq`/`dueHead`/`dueTail`/`dueCount`/`pruneCursor`), and a per-entry deadline fixed at
publication with status `PUBLISHED | PROVEN | DISCARDED`. If page 04 chooses a different field
set, the budget is re-derived from it and the arithmetic shown — no silent drift.

**Rule-index rows owed** for page 04's `FI-10`–`FI-14`, `DA-07`–`DA-10` and `L1-14` if those ids
land, plus any id the page-05 pass adds. A final **registration audit** must confirm, in both
directions, that every rule-side name has a register row and every row is referenced by a rule,
and that every rule id in the specification has an index row.

