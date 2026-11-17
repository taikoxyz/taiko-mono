# Actual payments across corrective rollback

`EtnaRollbackPayments.tla` is a finite observer/scheduler over unchanged
`EtnaVerifierRollback` (M09) and its actual `EtnaSettlement` actions. It is intended
to exercise actual pre-correction transfers, preserve their raw state through the
specified atomic correction, and complete one legitimate remaining payment after
fresh proof. It does not provide a concrete corrective-upgrade API.

All three programs retain `RollbackInit` and setup0, Replay, heights2,
generations2, nonce4, time1 and all original correctness flags TRUE. They bypass
only the old Setup/Runtime scheduling restriction that makes Upgrade the first
post-setup action. No state setter or copied settlement/payment engine is added.

The common history is FreshGood1, authorize1, confirm bond0, seed Legit, inject
Bad2, confirm bond1, seed Forged, tick to block101, actual Withdraw1 and actual
Forged retry **before** PauseBoth/Upgrade. Reads inspect voided2 and retained1;
after unpause the old caches, Forged retry/proof and stale recovery authority are
attempted. Legit is freshly reproved against Good1 and retried twice. The first
retry consumes its remaining escrow; the repeated actual attempt transfers zero.

`NonceBefore` additionally calls actual OwnerInvalidate before containment, so
current nonce1 must become2 although the old authorization still carries0.
`HeightReuse` instead calls actual FreshGood2 after unpause, replaces absent
Bad2 with Good2, and reproves Legit against that new identity. Generation stays0:
Good2 has snapshot20, not block101. Numeric height2 is reusable; authority belongs
to the current canonical identity.

The imported cash value1/stake1 is separately labeled historical baseline. Actual
Withdraw1 contributes stake1, actual Forged retry value1 and later Legit retry
value1, yielding final value3/stake2. Only the two SeedMessage calls charge fee1
each. The full witness requires those executed receipts, both consumed escrows
and completed flags, bond1 principal0/withdrawnTRUE, preserved bond0 principal1,
fresh proof, fee preservation and the zero-transfer repeat. Missing transactions
cannot be supplied by the imported baseline.

Both cache/retry timestamps are100, equal to the first bad block, so correction
revokes both messages, including earlier Legit in that same block. Withdraw1
already clears confirmed1; its zero after Upgrade is not new confirmation
invalidation evidence. The raw history captures the actual prior confirmations
and withdrawal separately. Stale Recover is otherwise generation/checkpoint/
deadline compatible but fails the changed current nonce.

Each attempted call appends complete raw state/cash/base/journal before and after,
actual enabledness and execution. Enabled original actions always execute unless
a selected missing-action control deliberately suppresses that named call. Bad
mutant actions are not filtered by observer expectations. Every raw value/stake/
per-message fee delta is summed, including negative deltas on non-payment calls.
A separate literal per-action/payee amount audit disallows clawback/repayment
cancellation; the telescoping sums alone are not an oracle. No observer relies
solely on overwritten messageTransfers slots. Dedicated immediate Upgrade audits
read actual primed cash and completed/escrow, because M09's upgrade journal uses
unprimed afterCash and its existing payment invariant omits completed.

The normal config checks all three complete histories with original applicable
invariants and new raw audits. Three witness configs deliberately fail only
`PaymentTerminalNotReached` after full positive completion; these are existential
progress evidence, not liveness. Two focused configs isolate raw cash and completed
preservation faults so unrelated old invariants cannot mask their intended kill.
One missing-required config nondeterministically suppresses each listed required
call in every applicable program and must exhaust without a complete witness.
These omissions are structural witness-loss checks, not additional independent
protocol coverage. Read/cache/refusal probes retain their place in full witnesses.

Use the existing checker with supplied local tools and disposable output:

```sh
python formal/etna/check.py --java "$JAVA" --tlc-jar "$TLC_JAR" \
  --output-dir "$TLC_OUTPUT_DIR" --case rollback-payments-normal \
  --case rollback-payments-witness-core \
  --case rollback-payments-witness-nonce-before \
  --case rollback-payments-witness-height-reuse \
  --case rollback-payments-missing-required
```

Actual results, private-source fault/restoration evidence and independent review
belong in the external execution report and shared catalog after execution. This
guide describes intended obligations and does not assert an unexecuted pass.

Source mapping: canonical SPEC commit d18357214fab30ea512ae9858a11699806d72ba1,
blob649548c58d6629dd85143b33efd3644a3bb71509; RECOV-8-25/26/27/27a/29/30/31/35,
STAKE-4.1-27/28 and rollback/withdrawal/retry acceptance requirements. Current
workspace correspondence is scoped to reviewed991e06f6/blobaf8c32cc/SHA753d3188;
this is no whole-SPEC equivalence or editorial-only claim.

InjectedBad remains the explicit verifier-failure premise. Corrective Upgrade is
an atomic specified macro: real proxy/storage migration, partial failure, actual
consumer authentication, token callbacks, fee currency, node reconciliation and
cryptographic proofs remain outside this finite history. Q02 concrete corrective
implementation and D01 shared-provider deployment acceptance remain WAITING.
