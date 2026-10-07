# Increment 4 - ship record (narrow forced inclusion)

**Verdict: increment 4 has met the convergence bar and ships.**

The bar, set in `PLAN.md` before the fact: two consecutive review rounds with no Critical and no High. For an increment the bar applies to the increment.

| Round | Critical | High | Medium | Low | Verdict |
|---|---|---|---|---|---|
| 1 | 1 | 1 (all four reviewers) | 2 | 2 | not clean |
| 2 | 1 (all four, unfixed) | 0 | 0 | 0 | not clean |
| 3 | 1 | 0 | 0 | 4 | not clean |
| 4 | **4** | 0 | 2 | 2 | not clean |
| 5 | 0 | 0 | 1 | 4 | clean |
| 6 | 0 | 0 | 1 | 3 | clean - confirmed |

Rounds 5 and 6 are the two consecutive clean rounds. Round 5's Medium changed RULE text (the no-room
discharge ground stated two conditions in one sentence), so it was fixed and round 6 re-confirmed the
fixed artifact rather than shipping on the pair as it stood. Round 6's findings are all course and
disclosure text; no rule changed after it.

## What ships

**A narrow inclusion obligation, in one unit.** A published record is an entry in the D-11 publication
register; the obligation is registered **positions per batch**, and `CONS-01(v)` is a per-block order and
non-omission duty with no per-block count and no per-block gas quota. A batch must satisfy
`c' >= min(d(A), c + FI_MAX_PER_BATCH)` **unconditionally** - the preserved "unless the window is
shorter" waiver is deleted, not narrowed. Enforcement is **in the proof** (`PRF-04(vi)`), never an
admission gate: `L1-04`'s no-gate property survives.

**A total resolution walk.** A position resolves by walking the record's transactions **in the record's own
order**; each either executes or is discharged at its turn. The turn is pinned by position, and the
discharge ground has four conditions read at that turn: the declared nonce is not the sender's nonce; the
balance is below the declared maximum charge; the sender has code (EIP-3607); or the block in which the
turn lies had no room - the same remaining gas the per-block duty reads. The three modes
(executed, void, dead) form a **partition**, with dead tested first and unconditionally and the void
limbs live-only. Totality is a rule property: no published record can pin the frontier.

**The counterparts that make it enforceable.** Per-record payload index order is a **block-validity
rule** in `CONS-01(v)`, so an out-of-order inclusion is invalid rather than silently unresolved, and the
proof-side condition is kept as the guest's check. Seven byte-decidable classes (A)-(G) void a record
whose transaction no valid block can carry, and the fee requirement is a **registered policy floor**
(`FI_MIN_EXEC_FEE_CAP`) rather than a read of the live base fee, which a producer can move.
The published byte string is pinned as the `PRF-07(0)` batch payload - one object, one identity.
The prune is deletion-only behind a stored cursor, never writes a frontier and is never read by land.
**No new slashable offence is created**: the forced-inclusion offence rows stay tombstoned.
No forced-inclusion state is read by the withdrawal root, its attestation, the k-family check, the veto
or exit eligibility.

## The guarantee, stated as it is

**This is not a latency guarantee.** What is bounded is **exclusion per unit of the censor's L1
spending**, conditional on at least one honest or rational producer and on L1 including the user's
publication. A pure censor that refuses the front record halts its own frontier rather than censoring it;
a publishing censor can front-run re-publications at roughly one L1 publication per deadline window; and
**an L1-censored publication still cannot be forced**.

**The general inclusion list stays absent** (`FI-PLANNED-01`): this increment revives the narrow FI family
and nothing else.

**Falsifiers carried, with their status named rather than implied:** F-FI-1 (the capacity relation's
gas-limit schedule premise, Open), F-FI-2 (**arrivals exceeding the drain - Open and deliberately
unfixed**: no per-publisher bound was adopted, because a condition on `publish()` is outside what D-12
authorises), F-FI-3 (a discharged transaction may become executable later through the sender's own
further transactions or a third-party credit; re-publication is the remedy), F-FI-4 (a record can age
out to dead instead of being included), F-FI-5 (the honest-producer and L1 condition), F-FI-6 (the
deadline is an upper bound, closed inside the envelope), F-FI-7 (the fee-schedule premise that makes the
policy floor safe, Open) and F-FI-8 (an execution-validity rule outside classes (A)-(G) and the turn
pre-state, Open).

## What this increment demonstrated

Six Criticals across four rounds, **every one the same class** - two clauses individually true and
jointly false - and **every one created by a repair, not by the design**. The mechanism was sound from the
start; what failed was the text describing how its clauses interact.

The verified property, as the confirming round stated it: with the duty and the walk scoped to one turn,
the turn pinned by position, the order rule plus the proof-side condition, classes (A)-(G), the four
discharge conditions read at the same turn against the same remaining gas, and the fee floor's premise -
**there is no admissible block, publisher input or producer choice that leaves a position in no mode or
makes a certifiable range unprovable within the stated premises**, and the five Open falsifiers are what
would break it.

Three habits earned that result, and they are the increment's real output: **replace a universal claim
with an enumeration plus a named residual**; **give every duty its consensus-side or proof-side
counterpart**; and **verify quotations, counts and enumerations by measurement, not by reading** - because
a claim, a count and a quotation each outlive the rule they describe.