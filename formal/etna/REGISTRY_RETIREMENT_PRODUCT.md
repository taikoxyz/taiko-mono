# Pending-funded admission and retirement product (J03)

## Scope and authority

`EtnaRegistryRetirementProduct.tla` extends the unchanged `EtnaRegistry` Init and
actual actions. Its only new state is a selected permutation, attempt index and
append-only raw receipts. `setup` stays zero. The product is six finite schedules
of 21 attempts, with no `AllActions` continuation and no business-state setters.

Authority is SPEC commit `d18357214fab30ea512ae9858a11699806d72ba1`, blob
`649548c58d6629dd85143b33efd3644a3bb71509`, SHA-256
`4d81d5dadcee3eb94ff554ec5a8144a47888dd5a8263ac5852422a0f1d1dd71b`.
The scoped current-byte correspondence does not replace this historical pin.
Admission and displacement follow STAKE-4.1-13a/14a/14b; pending funding and
activation follow STAKE-4.1-15 through 22; confirmation, withdrawal and historical
slashing follow STAKE-4.1-25 through 34. Selection uses COMM-4.3-2/3/7/17.
Forfeiture follows FORF-4.4-4 through 15/18. Ordinary recovery's exclusion and
actual generation advance project RECOV-8-40a/41/42/47/49/50.

Bounds: two slots, at most three issued bonds, `MaxNow=6` (`Never=9`), one top-up
per id, registration amounts `{1,2,4}`, top-up amount 2 and forfeiture denominator 2. `PreparedWorkflow=FALSE`, `FixedRegistrationBlocks=FALSE`; every inherited
correctness switch is TRUE. Delays and currency are normalized units. This does
not establish concrete capacity, admission indexing, storage layout, signatures,
DAO authorization, callbacks, gas, or a refinement to deployed source. R01 stays
OPEN.

## Literal program and expected operational observations

Every enabled unsuppressed action executes before observation. An expected
refusal never guards dispatch. In particular, `Register(2,2)` is enabled and
executes its rejection branch: enabledness is not acceptance. Receipts preserve
complete before/after `r`, `audit`, `event` and `setup`, as well as the actual
call, enabledness and execution flag.

| Attempt | Actual call                | Literal observation after execution                                                                                                                                                     |
| ------- | -------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1       | Register(0,1)              | Bond 0/key 0/owner 1 takes slot 0, eff 1, active 2, exit 9; vault 1.                                                                                                                    |
| 2       | Register(1,1)              | Bond 1/key 1/owner 1 takes slot 1 with the same timing; vault 2.                                                                                                                        |
| 3       | Tick to 2                  | Closed snapshot 1 has bonds 0/1, eff 1 each, active 2, exit 9.                                                                                                                          |
| 4       | Tick to 3                  | Closed snapshot 2 has the same entries.                                                                                                                                                 |
| 5       | SelectSnapshot(2,TRUE)     | Initialized; members {0,1}, power 1 each.                                                                                                                                               |
| 6       | Topup(0)                   | Bond 0 eff 1/pending 2/ready 4; vault 4.                                                                                                                                                |
| 7       | Topup(1)                   | Bond 1 eff 1/pending 2/ready 4; vault 6.                                                                                                                                                |
| 8       | Tick to 4                  | Closed snapshot 3 still has eff 1 each, excluding pending 2.                                                                                                                            |
| 9       | Register(2,2)              | Enabled and executed, rejected against total stake 3; complete operational r unchanged, nextId 2, key 2 unused, vault 6.                                                                |
| 10      | Register(2,4)              | Accepted at tied lowest index 0; bond 0 loses holds only and exit becomes 4, retains owner 1/key 0/eff 1/pending 2/ready 4; bond 2/key 2 takes slot 0, eff 4/active 5/exit 9, vault 10. |
| 11      | Activate(0)                | Actually disabled after displacement; complete raw state unchanged.                                                                                                                     |
| 12–14   | Selected permutation below | All three real actions enabled and executed at time 4.                                                                                                                                  |
| 15      | Slash(0,0)                 | Current generation 1; historical-generation evidence takes remaining pending 1, clears ready and eff, retains exit 4; sink total 3, vault 7.                                            |
| 16      | Tick to 5                  | Snapshot 4 contains bond 1 eff 3/active 2/exit 9 and bond 2 eff 4/active 5/exit 9.                                                                                                      |
| 17      | SelectSnapshot(4,FALSE)    | Only bond 1, power 3: bond 2 active 5 is too late for snapshot 4.                                                                                                                       |
| 18      | Confirm(0)                 | Snapshot 4 exactly covers exit 4; first confirmation is 5.                                                                                                                              |
| 19      | Tick to 6                  | Closed snapshot 5 contains the same entries as snapshot 4.                                                                                                                              |
| 20      | SelectSnapshot(5,FALSE)    | Members {1,2}, powers 3/4.                                                                                                                                                              |
| 21      | Withdraw(0,2)              | Actual enabled public zero withdrawal; bond 0 withdrawn, owner/confirmation/principal/ready cleared; slot 0 still bond 2, slot 1 still bond 1, lifetime used/forfeit key 0 retained.    |

| Program | Attempt 12         | Attempt 13         | Attempt 14         |
| ------- | ------------------ | ------------------ | ------------------ |
| 1       | Activate(1)        | OrdinaryRecover(0) | Forfeit(0)         |
| 2       | Activate(1)        | Forfeit(0)         | OrdinaryRecover(0) |
| 3       | OrdinaryRecover(0) | Activate(1)        | Forfeit(0)         |
| 4       | OrdinaryRecover(0) | Forfeit(0)         | Activate(1)        |
| 5       | Forfeit(0)         | Activate(1)        | OrdinaryRecover(0) |
| 6       | Forfeit(0)         | OrdinaryRecover(0) | Activate(1)        |

Activation moves bond 1's pending 2 into effective stake 3 and clears ready.
Recovery really advances generation 0 to 1 and retains the earlier exit 4.
Forfeit takes ceil(3/2)=2, deducting effective 1 before pending 1, leaving
0 effective/1 pending/ready 4 and setting the lifetime forfeiture flag.
Both recovery and forfeiture retain exit 4 in every order. Before withdrawal,
bond 0 remains owner 1/key 0 even at zero balance; after withdrawal key/issued/exit
remain while owner and confirmation clear. Bond 3 is never issued.

`LiteralState(n)` describes the complete operational r at every normal prefix,
including every bond field, slots, calls, keys, flags, times, generation,
snapshots, members and powers. Its literal row-position tables independently
specify when each of the three calls should have happened. It never consults
inherited decision helpers or journals. `RetirementLiteralAudit` checks every
before and after row, so a later terminal cannot conceal an intermediate error.
The receipt frame audit also checks continuity and complete equality for
unexecuted attempts. Inherited invariants supplement these independent rows.

Cash is reconstructed from actual before/after vault deltas, separately from
inherited audit totals. Normal deposits are 1+1+2+2+4=10, sinks 2+1=3, payments
0, terminal vault 7 backing effective stakes 3+4. Historical closed snapshots
1/2/3 remain the original eff-1 entries throughout retirement.

## Configurations and controls

There are twelve new configurations. `normal` checks all six paths against
inherited and raw audits. `witness-1` through `witness-6` each select exactly one
permutation and expect the precise `RetirementCompleteNotReached` violation at
the full 21-attempt terminal. These are reachability witnesses, not failures of
the source protocol. `admission-audit` checks only the dedicated immediate
`RegistryRawAdmissionAudit`; it is expected to pass on the baseline and can be privately
retargeted to that precise expected violation for the actual source fault.

`missing-replacement` suppresses only attempt 10 while retaining actual
enabledness. Attempt 11 then becomes enabled and MUST execute, activating bond
0 to eff 3/pending 0. Recovery, forfeiture, historical slash and public zero
withdrawal still run. Its positive partial endpoint has deposit 6/sink 3/pay 0,
vault 3, nextId 2, key 2 unused, bond 2 unissued, slot 0 empty after withdrawal,
and only bond 1/power 3 in the final committee. `partial-replacement` expects the
precise `RetirementPartialNotReached` violation at this endpoint.

`missing-withdrawal` suppresses only attempt 21, which remains actually enabled.
Its endpoint is exactly normal row 20, with zero principal and sufficient time,
but bond 0 still unwithdrawn/owner 1/confirmed 5. `partial-withdrawal` witnesses
that partial endpoint with the same precise invariant. The two missing-action
PASS configurations additionally assert absence of the full terminal. Such
absence alone earns no progress credit: retain actual partial receipts and the
positive endpoint violations. Omission modes deliberately do not check the
normal full-history literal invariant or claim a safety kill.

## Actual-source challenge and execution gate

In a private immutable runtime copy only, uniquely select this inherited text:

```tla
SlotBalance(s) == IF r.slots[s].occupied THEN Balance(r.bonds[r.slots[s].id]) ELSE 0
```

Replace only the occupied return `Balance(r.bonds[r.slots[s].id])` with
`r.bonds[r.slots[s].id].eff`. Require exactly one selector match and record
baseline/mutant SHA-256. The altered actual Register(2,2) now sees effective 1
instead of total 3 and must actually accept at receipt 9: transfer 2, consume id
2/key 2, displace bond 0, vault 8. The dedicated audit must fail immediately at
that receipt, before attempt 10. Parser/type failures, earlier/wrong invariant
failures, timeouts or failure to execute the call are inconclusive. Restore the
same private source bytes and rerun the same cases; require all six full normal
witnesses again. An independent tester selects a distinct challenge.

Phase A freezes source/config/guide bytes after repository Prettier formatting
and full self-read. No TLC, SANY or test engine runs before root's independent
literal/dispatch readback and explicit GO. After GO, source/catalog/document
writes remain stopped throughout author and independent guarded execution.
Use the existing managed Python, exact pinned Java 17 and TLC 1.7.4 jar, inspected
`check.py` and `conformance/run_isolated.py`, clean environment, read-only copied
inputs/dependencies, disposable writable output and offline namespace. Retain
raw logs, command/input/tool hashes, copy provenance and same-copy restoration.
No host Java, downloads, native/Forge/signing or live-chain fallback is allowed.
The ignored task report records actual outcomes; this guide alone reports no
runtime state count or successful engine result.
