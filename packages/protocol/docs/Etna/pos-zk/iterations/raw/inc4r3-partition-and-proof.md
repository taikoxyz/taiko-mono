# Increment 04 round 3 — the partition and its enforcement

**Reviewer:** independent adversarial reviewer, increment 4 round 3, angle partition-and-proof. **Snapshot:** 94255e9df, extracted with git archive.

**Counts: Critical 0 · High 0 · Medium 0 · Low 1.**

The per-transaction walk is real and the three modes now partition the cases. I enumerated every overlap the round asked for against the shipped text, and each resolves to exactly one mode; PRF-04(vi) and FI-11(2)(4) mirror the same precedence, the guest must recompute each turn pre-state and reject a false discharge, and FI-11(3)(a)'s unconditional advance plus the total walk make the no-halt claim true. The single Low is implementer alignment on the byte-invalid limb's decision classes, not a gap in the partition.

---

## F1 — The byte-invalid limb's decision classes are given by example only, so two guest implementations can disagree on which transactions "cannot be executed from the record's own bytes"

**Severity: Low.** Rationale: totality of the walk depends on every non-executable transaction falling into either the discharge conditions (nonce not equal to the sender's nonce at its turn, or balance below the declared maximum charge) or the record-level byte-invalid limb. The limb is general and correct, but its only example is a chain-id mismatch; a guest that implements the enumeration as "chain id only" leaves a transaction that is byte-invalid for another reason — an unrecoverable signature, or a declared gas limit below the intrinsic gas of its own data — neither executable nor discharged, so the position is unresolved and FI-11(3)(c) rejects the proof: a narrower version of the round-1/2 pin, reachable only by the record's own publisher but not visible to it. This is a guest-alignment item, not a partition gap.

**File + rule id.** spec/04 FI-13(1)(b), second limb: "it contains a transaction that cannot be executed from the record's own bytes (**for example** its chain id does not match (2)(iii)), so no batch can execute it at any pre-state"; spec/05 PRF-04(vi): "live at A and containing a transaction that can never be executed from its own bytes".

**Assumptions.** None. **Attack trace.** None adversarial: a publisher (including the user) publishes a record whose transaction has, say, a gas limit below the intrinsic gas of its data, nonce equal at its turn and a sufficient balance; a guest with only the chain-id check finds no discharge ground and no execution, so the proof is invalid until the record is dead — the same shape as R4R1-M-01, confined to the byte-invalid class the guest fails to recognise.

**Fault-model verdict.** N/A (implementation alignment; the rule is total as written). **Attacker cost.** None.

**Requirement affected.** FI-13(5)'s totality claim as implemented; PRF-04(vi)'s single-predicate requirement.

**Suggested repair.** Enumerate the byte-decidable classes in FI-13(1)(b) and have PRF-04(vi) name the same list: chain-id mismatch, unrecoverable/invalid signature, payload that does not decode under PRF-07(0) (already caught by (2)(i)'s over-bound limb), and a declared gas limit below the intrinsic gas of its own data. One parenthetical; no mechanism change.

**Evidence.** spec/04 FI-13(1)(b), FI-13(2)(i)-(iii), FI-13(5); spec/05 PRF-04(vi).

---

## Partition verification (the enumerated overlaps, each against the shipped text)

FI-13(1) now states the precedence and the exclusivity: "(c) is tested first and unconditionally; otherwise the record is live at A, and the over-bound and byte-invalid limbs of (b) are tested before (a); and (a)'s walk and the discharge limb of (b) are disjoint, because (a) requires at least one transaction to execute and that limb requires none to execute."

1. **dead + over-bound** → (c) alone. "a record that is dead at A is dead whatever its size, its contents or its discharge state, and (a) and every limb of (b) never apply to it."
2. **dead + byte-invalid** → (c) alone, same sentence.
3. **dead + a transaction of it in the executed payload** → (c) alone (dead first and unconditional); the executed transaction is an ordinary payload transaction.
4. **live + over-bound + a transaction in the payload** → (b) alone. "this limb is tested before (a), so a live over-bound record is void even if one of its transactions appears in the batch's executed payload, and its mode is fixed by its own immutable bytes, never by the producer's inclusion choice."
5. **live + byte-invalid + a transaction in the payload** → (b) alone, same precedence (byte-invalid is a (b) limb tested before (a)).
6. **zero transactions** → (b) alone. "a record with no transactions at all is void under this limb: there is nothing to execute."
7. **over-bound + all-discharged** → (b), one mode: "the limbs may hold together — a live, over-bound, fully discharged record is still one mode; the limbs are alternatives within (b), never separate modes."
8. **byte-invalid + all-discharged** → (b), one mode, same sentence.
9. **live + clean + mixed (some execute, some discharge)** → (a) alone, with the executed ones recorded executed and the discharged ones recorded discharged.
10. **live + clean + all execute** → (a) alone. **live + clean + all discharged** → (b) alone ((a) requires at least one execution). **live + clean + a transaction that can execute at its turn but is omitted** → unresolved, and FI-11(3)(c) makes the proof invalid: "that is the obligation of FI-11."

**FI-13(4) agrees with FI-13(1)(b).** Its limbs are live-only and it says so: "a record above any registered bound is void" is "corrected here to agree with (1)(b) — a dead over-bound or byte-invalid record is (c), and the frontier advance and the no-gas property are identical"; and "a live record every one of whose transactions is discharged at its turn, so that none of them executes" is void. FI-13(5) states the exclusivity and totality as a rule property.

## Enforcement verification

- **PRF-04(vi) mirrors the precedence.** "walked per transaction in the record's own order — applied in the precedence FI-13(1) states so that they partition the positions: dead first ... otherwise, for a record live at A, void (over-bound from its own immutable bytes — tested before executed ... — or containing a transaction that can never be executed from its own bytes, or every transaction discharged), or executed." FI-11(2)(4) repeats the same order. The guest and the rule cannot disagree on the mode of a position.
- **A false discharge is rejected.** "the guest MUST recompute the pre-state its turn reaches in the batch's own execution and MUST accept the discharge only if the transaction's nonce does not equal the sender's nonce at that pre-state, or the sender's balance at that pre-state is below t.gasLimit x t.maxFeePerGas + t.value; a claimed discharge that fails either condition is invalid"; and "MUST reject a proof in which a transaction that can execute at its turn does not appear or is claimed discharged although it could execute, because such a position is unresolved and the walk is total (FI-13(5))."
- **No-halt.** Every live position is resolved either by a (b) limb decided from its own immutable bytes or by the walk (execute or discharge, per transaction, in the record's own order); the mixed-forceability record of R4R1-M-01 now resolves with the executable transactions executed and the others discharged, and the record is void only when nothing executes. The frontier advances at least one position per accepted batch (FI-11(3)(a), R = min(d(A) - c, FI_MAX_PER_BATCH) with R >= 1 when the obligation is non-empty), and FI-11(2)(3) now states "the walk of FI-13(1) is total, so W is the whole live prefix of the window and the work of a live position is bounded by its own record's transactions" — so the capacity condition is a bound on work that always exists, and FI-12(5)'s claim holds. The old record-level grounds ("all of its transactions", "none of whose transactions is forceable") are expressly superseded in FI-13(1) and PRF-04(vi).
- **The immutable-half ground has no producer-set input.** The byte-invalid limb reads only the record's published byte string and the registered/ L1-derived chain id ((2)(iii); the chain id is a config/journal constant, PRF-02(5)). A producer cannot inject a bad transaction into someone else's record (the bytes are fixed at publication, DA-07(3)) and cannot alter the record's decoded contents.
- **The batch-wide turn pre-state opens no new void ground.** The turn pre-state depends on the batch's execution order, but only the account's own signed transactions can move its nonce or its balance: incoming transfers only make a transaction executable, and no other account's signature can consume the sender's nonce or spend its balance. FI-13(2) states this ("ordering enters the walk of (1) only through the sender's own signed transactions, never through a transaction of the producer's") and FI-13(3) qualifies the anti-void claim correctly: "if the sender has signed no other transaction that supersedes or defunds it, a transaction that can execute at its turn must be executed, never discharged, and a producer that omits it makes the proof invalid." The residual — a transaction discharged because the sender's own further signed transaction consumed its nonce or spent its balance — is F-FI-3, carried Open and disclosed, not a new ground.
- **L1-04, the exit, the tombstones and the no-new-offence position still hold.** FI-11(1) keeps enforcement in the proof (no rejection for a non-empty register, no submitter coverage claim, the settlement write an effect of acceptance) and FI-12(1) keeps the capacity condition in proof validity; the exit non-interaction rule at spec/04 04:743 is unchanged and the membership/exit page contains zero FI names (grep count 0); ECON-04 clause (6) and ECON-13(4) remain tombstones and PRF-04(vi) states "the rejected proof is the whole enforcement".

## Strongest attack considered and dismissed

A batch builder can settle a forced record as void — no execution, frontier past it — by including the sender's own conflicting signed transaction from the public mempool before the record's turn (nonce consumed or balance spent). This is real but it is the disclosed F-FI-3 residual, it requires the victim's own signature, the victim's remedy is the permissionless re-publication of DA-09(2), and FI-13(3) states the qualification rather than claiming an absolute anti-void property. The other griefing shape — filling the register with void or dead records ahead of a specific one to extend its wait — is F-FI-2/F-FI-4, the arrivals-exceed-drain Open, and the guarantee is exclusion per unit of the censor's L1 spending, not latency. Neither is a new defect.

## Verdict

**Clean at the bar: Critical 0, High 0, Medium 0, Low 1.** The partition is genuine at every anchored view (dead-first removes the dead overlaps, the live-only limbs of (b) are decided from immutable bytes before the walk, (a) requires at least one execution and the all-discharged limb requires none, and a zero-transaction record is (b)); FI-13(4)/(5), FI-11(2)(4) and PRF-04(vi) agree on the precedence and the guest is required to recompute each turn; the no-halt claim is now supported by the rule, not asserted. **Safe to ship:** yes — apply F1 as a one-parenthetical enumeration of the byte-invalid classes in FI-13(1)(b) and PRF-04(vi) alongside any copy edit; it is not a hold. This is the first round in which the R4R1-M-01 class is closed in the artifact.
