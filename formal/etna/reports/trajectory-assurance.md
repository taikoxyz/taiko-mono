# Trajectory principal conservation and signing/exit assurance

Authority: SPEC.md and ACCEPTANCE.md at `39ebefbf33a2702b750e0fb0db7d2a40ff8e8480` (#22303). This extension adds supplemental results to #22292 without changing the seven headline premises, H1–H3, production implementations or the specification.

## Principal conservation over every original trace

`Accounting.protocol_trajectory_conservation` lifts **every** `ProtocolState.Trace` to a receipt-bearing `Accounting.Trace` and proves:

```text
initial held principal + cumulative deposits
  = final held principal + withdrawals + slash bounty + slash/forfeit sink payouts
```

Held principal sums `effStake + pendingTopUp` over allocated slots. Deposit receipts use the accepted registration/top-up amount. Withdrawal, bounty and sink receipts use the values actually returned by `Staking.withdraw`, `slashDouble` and `forfeit`. Receipts are never defined by subtracting the final balance from the initial balance. Activation, exit requests, confirmation, landing, FI enqueue/sweep, recovery, nonce invalidation and rollback move no TAIKO principal. Rollback does not undo an irreversible payout or restore spent collateral.

`step_lift` and `trace_lift` cover every original constructor; `step_project` and `trace_project` connect the observer back to the original machine. Failed observations require an actual original function returning `none` and add zero-flow stutters. Failure does not advance this observer's L1 clock; the next successful transition observes elapsed time. No existing successful transition is omitted to make conservation hold. The correspondence and generic sum helpers are explicitly unsourced bookkeeping: audited, but never clause/claim evidence.

The sole slot-balance initialization premise for the general identity is `ReleasedZero`: released slots contain no principal, including outside the allocated range. This is derived from `RegistryHistory.empty` through registry and protocol trajectories. The stronger `SlotGood` also proves unallocated slots carry zero. A kernel-checked raw state with a released slot holding 13 units loses those units when reused for a deposit of 5; another theorem proves it unreachable from the empty lifecycle. This is an initialization boundary, not a reachable design counterexample. A configured deployment with existing deposits can use a verified initialization prefix or establish the invariant directly; `Deployment.Genesis` alone is not silently strengthened.

The mixed regression covers all eight original successful constructor kinds, four failed-call stutters, pending activation, partial and full forfeiture, double slashing, withdrawal, slot reuse, recovery and confirmation rollback. Its independently recorded totals are:

```text
0 + 412 = 0 + 148 + 22 + 242
```

This comprehensive fixture uses small configured units and abstract accepting landing/recovery adapters; it is not itself a launch/deployment or valid-chain witness. `TrajectoryRegression.initialized_rotation_principal_conserved` separately combines the actual initialized non-vacuity deployment, a valid decoded ordinary rotation chain, standby deposit and old-validator withdrawal: initial and final held principal are each one TAIKO, and deposits equal withdrawals at one TAIKO.

ETH is accounted separately. Existing `ProtocolState.trace_preserves_core` preserves `FeeConserved`, namely `feeAdmissions + forcedETH = ethBalance + swept`, over original traces under the initial `Core`. FI fees never become TAIKO deposits. `Forced.extraETH` models force-sent ETH separately; it is not a new public `ProtocolState.Step` constructor in this extension.

These are logical principal/fee identities. Equality with actual ERC20/ETH custody still requires matching initial endowments, exact successful transfers and atomic failure in the implementation. Fee-on-transfer/rebase behavior, callbacks, token balances and production transfer wiring are not verified here.

## Signing rights, lockup and evidence window

The [signing analysis](signing-escrow-analysis.md) gives theorem statements and checked witnesses. The principal results are:

- Starting with no future-dated confirmations (in particular, none), retained confirmations never lie in the future. From an initially unconfirmed world, new confirmations cannot be backdated, across arbitrary original traces.
- Withdrawal uses the full fixed `withdrawalDelay` in L1 blocks after the retained confirmation, pays the entire remaining principal and clears it. Unconfirmed entries never withdraw, however long a halt lasts. Ordinary repeated confirmation, slash and forfeiture do not reset the clock; rollback clearing requires fresh confirmation and the full delay again.
- Current-snapshot coverage is proved under explicit `SnapshotTrace` discipline: ordinary snapshots grow and exceptional rollback rechecks confirmations. Arbitrary unrestricted landing inputs do not receive this premise automatically, and rechecking an arbitrary restored number does not authenticate it.
- From a zero-slot structurally valid initial state, lifetime key uniqueness and exact effective-exit history visibility are derived from actual transitions. A key with finite effective exit E stays excluded at **every cutoff >= E**, through arbitrary future steps, withdrawal, slot reuse, recovery and rollback.
- A built committee excludes the confirmed key when its selected cutoff is at least the covered confirmation-state snapshot. The missing authenticated-prefix-to-cutoff bridge is explicit; there is no assumption that the desired collateral conclusion already holds.
- A signer generation, once retired, remains closed through arbitrary signatures, later domain switches and reopened sessions.

## Properties that do not follow

**Continuous positive backing of fixed voting power is false.** The accepted full-slash regression starts with all seven headline premises and a Byzantine member holding one sixth of power. Its whole principal is slashed, but the current generation's fixed committee still assigns it positive power above the current checkpoint. This is a design limit if continuous collateral backing is intended: the specification would need to define how punished power stops being usable before a later committee activation/recovery. The existing fixed-snapshot rules do not supply that guarantee. The member's punishment has already been executed; this is not early withdrawal and does not violate the less-than-one-third finality assumption. No actual new wall-clock signature event is modeled.

**Historical validity does not imply current collateral.** An ordinary initialized rotation, with no recovery/rollback, lets an old key confirm and withdraw after the full delay while its height-1 signature remains historically valid. The old key alone cannot commit at fresh height 13 in that witness. This is the intended weak-subjectivity boundary; authenticating the latest L1 checkpoint is essential.

**The fresh-signing bridge is now conditional on explicit view and adapter inputs.** `Built` alone accepts arbitrary sorted archive/reference inputs, and `World` lacks the actual local EL tip and signature creation events. Neither the seven headline premises nor the signer trust booleans connect the actual trusted extension, selected cutoff, finalized-L1 checkpoint and real signing event. The new [signer/prefix connection](signing-prefix-connection.md) adds a typed local prefix, actual signer event and message/key binding, and derives the cutoff relation from accepted provenance and checkpoint inclusion. Global view freshness, production producer/adapter enforcement and rollback revalidation remain obligations; a full typed lagging-view counterexample explains why they cannot be inferred from trusted booleans. This is not evidence of a SPEC-compliant withdrawal/signing exploit.

**An available evidence period is not timely evidence delivery.** These proofs provide the block-based waiting period. They do not prove observation/publication/finality of evidence or DAO action before withdrawal. Exceptional rollback additionally needs the authentic last-trusted snapshot and timely governance procedure, not just a numeric bound.

## Validation

The central gate passed: 851 exact theorem contracts, 142 checked property derivation chains, nine silent Lean regression modules, and all 164 Python tests. It checks exact theorem types and mechanically derived roles, standard axioms only, fresh kernel replay, unchanged headline premise use, source pins, deterministic artifacts, vector freshness, silent Lean regression modules, and Python mutation/regression tests. Seven independent receipt mutations remove a deposit/payout or introduce false flow on a failed call/rollback; each breaks the real conservation proof while preserving valid Lean syntax. The unmodified proof compiles silently.

A separate semantic reviewer found no Critical/Important findings in the extension. Review clarified the rollback-cleared confirmation clock and the decoded historical archive boundary. Current gate totals are recorded in the package README.
