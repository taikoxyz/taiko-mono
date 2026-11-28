# Verifier-failure corrective-upgrade boundary

`EtnaVerifierRollback.tla` checks a small specification-level corrective-upgrade
interface. It composes actual `EtnaSettlement` Land, authorization, Recover and Tick
actions through wrappers. It does not implement a corrective DAO upgrade or prove
that a deployed SignalService/Bridge supports one.

The source is `packages/protocol/docs/etna/SPEC.md` at commit
`d18357214fab30ea512ae9858a11699806d72ba1`, blob
`649548c58d6629dd85143b33efd3644a3bb71509`, especially RECOV-8-24..36,
RECOV-8.3, STAKE-4.1-26..29 and STOR-B-15/33. Bad-verifier acceptance is an
explicit injected failure outside the ordinary proof-soundness assumption. It is
not a newly discovered protocol counterexample. A real corrective-upgrade API,
node handling and concrete storage/cache migration remain an implementation GAP.

## Finite interface and workload

The latest corrected start/held checkpoint metadata is an imported fixture; the
model does not replay a start correction or claim that the correction writes a new
SignalService checkpoint (START-10-5c preserves the relevant Unzen checkpoint).
`StartLatest`/`StartSuperseded` are symbolic metadata labels, not storage migration
implementations.

Heights are 0..2, generations 0..2, nonce 0..4 and time 0..1. Time maps to L1
blocks 100/101; K=1 and one unit normalizes each message's escrow, fee and each
bond's principal. There are two messages and two issued bond interfaces. Bond0's
exit threshold is5 and bond1's20. Both confirmations occur in block100, while the
restored snapshot is10 (or5 at the latest corrected start). These are abstract
registry interface fixtures, not a proof of the full registry lifecycle.

Three source-valid _interface_ prefixes execute the wrapped base actions:

- **Replay:** trusted landing1, an authorization at c1, a legitimate cached/retriable
  message, bad landing2, then a second confirmation and forged message. The same
  generation/c1 authorization can therefore become relevant again after rollback;
  only its stale nonce rejects it.
- **Stranded:** the same history also executes ordinary recovery at c2 before the
  corrective upgrade. Rollback preserves generation/start2 while returning c to1;
  all Land attempts remain disabled until a newly authorized recovery starts at1.
- **NoTrusted:** a bad landing1 and ordinary recovery have no earlier trusted
  landing. Restoration uses the latest corrected start0, not the superseded start.

Every prefix pauses both consumers. The corrective upgrade is the first
post-prefix action. The checked suffix explores Tick, checkpoint reads, proof
attempts, cached empty-proof attempts, retry attempts, confirmations, withdrawal,
unpause, and new valid Land. Fresh authorize/Recover calls are exposed while the
preserved start is above c, with every bounded deadline available. Arbitrary
pre-upgrade scheduling, post-upgrade nonce-invalidation traffic and repeated
unnecessary recoveries are outside this external workload. This is not the full
product of the earlier registry, bridge, FI, node and consensus models.

The upgrade is an atomic normative interface. A failed/partial corrective-upgrade
transaction, actual proxy migration, signal cryptography, real bridge call failure,
QuotaManager, token callbacks and node reconciliation are not modeled. Ordinary
recovery's combined list-failure atomicity belongs to `EtnaRecoveryTransaction`;
that does not prove atomicity of an as-yet unspecified corrective upgrade.

## Checked behavior and independent observations

The upgrade restores c/FI head/active snapshot, keeps the current generation,
increments its current nonce, rechecks **all two fixture confirmations** by exit
threshold, and invalidates later checkpoint authority. Height0 stands for a held
start/Unzen checkpoint; valid checkpoint1 is retained. A later valid landing can
reuse voided height2. Root strings are injective symbolic identities; message
membership is a declared finite interface, not an MPT/circuit proof.

The immutable expected-checkpoint ledger records raw landing inputs separately
from the operational checkpoint table. Actual read and accepted/rejected proof
attempt outcomes are compared with that ledger. The upgrade receipt captures
actual pre/post fields and cash. Cached/retry calls use their operational flags;
a separate raw first-bad-block/original-authorization ledger observes whether an
old path actually accepted. A fresh valid proof is necessary to regain authority.
The block-granular cutoff deliberately revokes the legitimate authorization made
_before_ the bad transaction in the same block100 as well.

Actual retry transfers record external value and fee deltas. The legitimate
message can reprove at newly landed checkpoint2, complete with value1 and fee0,
and retain its earlier paid fee1. Withdrawal records actual cash deltas and
conserves each bond's remaining principal. Initially imported value-paid1 and
stake-paid1 represent irreversible external history: the upgrade cannot claw
those amounts back. The model does not execute the transactions that produced
those imported amounts. Forfeiture flags, fee-paid markers, exits, escrow and
principal survive the upgrade.

The stranded-origin property checks actual `ENABLED LandFresh`; stale
pre-rollback authorization checks actual `ENABLED Recover`, including a trace
where generation/c/deadline match again. No fairness, completion latency or
unconditional progress is asserted.

## Executed checks

Use the existing runner from the repository root, supplying local Java and TLC:

```sh
python formal/etna/check.py --java "$JAVA" --tlc-jar "$TLC_JAR" \
  --output-dir "$TLC_OUTPUT_DIR" \
  --case rollback-replay --case rollback-stranded --case rollback-no-trusted
```

The frozen module SHA-256 is
`9de72dfbc6149d07c0add856d11c71a9e113b3a80c26e1a0893cef2f3d48c832`.
All19 cases produced their exact expected results with 512MiB, one worker and a
45-second per-case limit. The three normal graphs exhausted with queue0:

| Profile   | Generated | Distinct |
| --------- | --------: | -------: |
| Replay    |    19,636 |    1,314 |
| Stranded  |    66,895 |    4,448 |
| NoTrusted |   134,417 |    8,858 |

Ten deliberate missing-guard/write controls fail at their named invariants:
nonce replay, base-only later landing retention, same-block confirmation filtering, later record retention, hiding
trusted records, cached authority, retry authority, fee repaying, origin-fence
rewrite and superseded-start restoration. Six existential reachability cases
fail deliberately at `*NotReached`: same-block confirmation split, stale auth
rejection, both old paths rejecting, canonical reproof/value/fee, fresh recovery
then Land, and latest-start restoration. Such expected invariant violations are
regression/witness evidence, not defects in the normative model.

First independent review found an assertion gap: removing only the base
`landings` voiding write left the initial Replay baseline green (1,314 distinct),
because its oracle observed the SignalService table alone. The repair captures
actual full base before/after records and requires complete retained-record
equality at/below the trusted restore height, plus absence above it. Normal
profiles also assert `NoFutureLandingRecords`; a base-only missing-void control
now fails exactly `BaseLandingRollbackCorrect`. This was a model-oracle gap,
not a specification or production finding.

The first executable core had one exhausted normal and two exact negative
controls before adding derived-authority actions. Full default expectation files
were written before those derived actions; this does not claim that every earlier
core file was created in strict tests-first order.

## Incomplete wider product

The earlier unrestricted runtime also allowed arbitrary pre/post-upgrade
Authorize/Recover/Invalidate/Confirm scheduling. Its Replay profile did **not**
exhaust: timeout45s; last emitted progress was 152,614 generated, 34,626 distinct,
19,607 queued (depth18). Those are intermediate counts, not final totals. It has
no PASS claim. Its exact model, base dependency and config are retained under
`experiments/m09-wide-runtime/`, together with portable rerun instructions.
The smaller checked prepared workloads do not establish that wider product.
