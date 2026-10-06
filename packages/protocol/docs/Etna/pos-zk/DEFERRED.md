# Deferred work register

Mechanisms **excluded from v1** by decision D-16, with what each was for, why it was deferred, what
blocked it, and what would revive it. Nothing here is abandoned: each entry is a scoped piece of work
with its findings preserved in `iterations/raw/`.

## 1. Narrow forced inclusion (D-12)

**For:** bounding the time a proposer can keep a published transaction out of the chain.
**Why deferred:** two independent round-6 reviewers found it **non-functional as written** - the
settled-frontier bound is waived by an exception with no referent, so under the only non-vacuous
reading the frontier never advances and the obligation is dead for the life of the deployment. A
separate finding shows `CONS-01(v)` is per-block at `FI_MAX_PER_BATCH` while the cap is per-batch,
which permits a configuration where no block can carry the prefix.
**Blocked by:** the frontier-advance rule, the unit mismatch, a steerable void predicate, and an
expiry discharge with no proof-side ground (`R6-D12-01`, carried unrepaired from round 5).
**Revive criteria:** one unit of account for the obligation; a mandatory frontier advance with no
waiver; a void predicate computed from the record's immutable bytes and registered constants only;
expiry as an objective proof-side discharge ground.
**Preserved:** `FI-10`-`FI-14` text in git history at `7917ba264` and the findings in
`iterations/raw/round5t-*.md` and `round6-d12-d14-repairs.md`.

## 2. Heartbeat eligibility (D-14)

**For:** letting a chain recover when a cohort stops participating, without removing anyone's weight.
**Why deferred:** its round-5 Critical (one signature was a permanent credential) was fixed, but the
fix has not been re-reviewed, and the mechanism depends on the stall-resolution path that is itself
deferred.
**Blocked by:** the per-window payload binding needs a fresh review; the pre-signing residual is
disclosed but open.
**Revive criteria:** review of the window-bound payload; a decision on whether the pre-signing
horizon needs closing.
**Preserved:** `MEM-13` text at `7917ba264`; finding `R5T-C-2`.

## 3. Governance stall resolution (D-15)

**For:** clearing a settlement stall without a permissionless recovery.
**Why deferred:** it did not survive its first review. A Critical showed that nothing consumes the
queued entry on execution, so any account can re-execute it and churn the generation - a
permissionless, gas-priced settlement-denial loop (`G-1`). Two reviewers independently showed the
timelock cannot be the exit window the rule claims (`G-2`, and round-5 `F1`/`F2`), and the
generation binding makes the first epoch-opening batch after a resolution unprovable (`G-3`).
**Blocked by:** an entry state machine with an `executed` state; a resolved exit contradiction; a
generation rule for the anchor certificate.
**Revive criteria:** fix the three Criticals and re-review the whole path.
**Preserved:** `GOV-04` text at `7917ba264`; `round6-gov-generations.md`.

## 4. Aggregation (D-13)

**For:** one proof object per batch whose soundness is n-of-m over independent backends.
**Why deferred:** it was never reviewed on its own terms, and it moves the trust to an aggregation
program while adding a proving cost that S1 has not measured.
**Revive criteria:** S1's aggregation-cost line, then a review of the family-bitmap enforcement.
**Preserved:** `PRF-15`, `L1-14`, `L1-13` text at `7917ba264`; `round6-data-proof-economics.md`.

## Cross-cutting items that outlive all four

- **The round-5/6 findings not specific to a deferred mechanism** are listed in
  `iterations/raw/round5t-*.md` and `round6-*.md`; the round-8 pass is in
  `iterations/raw/round8-*.md`. The exit contradiction is **repaired** (`MEM-15`(2a)/(2b) +
  `L1-13`(5)/`L1-11`): the exit's funding and witness dependencies are stated with their falsifier.
  What remains is disclosed rather than repaired — the unenforced proving split (`R8-EBA F3`, now a
  disclosed policy target of `ECON-02`(5)(e), not an on-chain bound) and the witness half of the exit
  assumption and falsifier (`R8-EBA F4`, a retention assumption no rule of the exit enforces). The
  un-relaxed-D5 wording had one surviving site, the blob-quantisation row of `09-parameters.html`,
  and it is re-based on D-11 in round 8; no other row argues from the superseded one-transaction
  form. *This closes review round 8 finding R8-EBA F7: the note lists the current residuals instead
  of calling repaired defects load-bearing.*
- **Phase B measurements** remain as planned: nothing in this register can be revived honestly
  without them.
- **The learning site** must be re-synced on **any** specification change, not only when a deferred
  mechanism returns, because it teaches the design as it stands; it was out of sync with the v1 exit
  until round 8 (`R8-EBA F2`). *This closes review round 8 finding R8-EBA F7: the sync trigger is any
  change to a live rule, not only the return of a deferred mechanism.*
