# Two-slot Nil replay across crash and recovery

`EtnaSignerNilReplay` is an additive finite scheduler and raw observer over the
unchanged `EtnaSignerCrash`. It uses actual `Init`, `AuthenticateTrust`, `Connect`,
`Request`, `Persist`, `Expose(TRUE)`, `Crash`, `Restart`, `AuthenticateRecovery` and
`Deliver` actions. Every correctness switch stays TRUE. The product is two slots,
payloads `{A,B,Nil}`, two symbolic signature salts, and eight explicit histories.
It does not explore the unrestricted original `Next` graph.

The authority is pinned SPEC commit `d18357214fab30ea512ae9858a11699806d72ba1`,
blob `649548c58d6629dd85143b33efd3644a3bb71509`, SHA-256
`4d81d5dadcee3eb94ff554ec5a8144a47888dd5a8263ac5852422a0f1d1dd71b`:
RECOV-8.2-1..6 and SYNC-9-10..14. No specification or original signer code is
changed. The persistent generation floor is this model's additional interface
contract; it is not a refinement of FilePV persistence.

## Frozen profiles and record identities

Each profile is `<<cut,firstSalt,deliveryTime>>`. `retrySalt=1-firstSalt`.
TLC configuration values cannot encode tuple sets directly. Configs bind
`NilProfiles <- NilProfileSet` for the aggregate product, or use one of eight
pure literal singleton operators such as `NilWritten0LateProfiles`. This changes
only the configuration representation; the exact tuple domain remains unchanged.
The full record has fields `domain`, `slot`, `payload`, `signature`; the tuple
shown below is the signature field, not a replacement for the typed record.
The payload and domain/slot fields must match each tuple literally.

| Profile          | First computed Nil tuple | Returned Nil tuple | Old B tuple | Fresh A tuple | Calls | Refused indices |
| ---------------- | ------------------------ | ------------------ | ----------- | ------------- | ----- | --------------- |
| Computed,0,Early | `(0,1,Nil,0)`            | `(0,1,Nil,1)`      | `(0,2,B,1)` | `(1,1,A,0)`   | 25    | 6,12            |
| Computed,0,Late  | `(0,1,Nil,0)`            | `(0,1,Nil,1)`      | `(0,2,B,1)` | `(1,1,A,0)`   | 25    | 6,12            |
| Computed,1,Early | `(0,1,Nil,1)`            | `(0,1,Nil,0)`      | `(0,2,B,0)` | `(1,1,A,0)`   | 25    | 6,12            |
| Computed,1,Late  | `(0,1,Nil,1)`            | `(0,1,Nil,0)`      | `(0,2,B,0)` | `(1,1,A,0)`   | 25    | 6,12            |
| Written,0,Early  | `(0,1,Nil,0)`            | `(0,1,Nil,0)`      | `(0,2,B,1)` | `(1,1,A,0)`   | 26    | 7,11,13         |
| Written,0,Late   | `(0,1,Nil,0)`            | `(0,1,Nil,0)`      | `(0,2,B,1)` | `(1,1,A,0)`   | 26    | 7,11,13         |
| Written,1,Early  | `(0,1,Nil,1)`            | `(0,1,Nil,1)`      | `(0,2,B,0)` | `(1,1,A,0)`   | 26    | 7,11,13         |
| Written,1,Late   | `(0,1,Nil,1)`            | `(0,1,Nil,1)`      | `(0,2,B,0)` | `(1,1,A,0)`   | 26    | 7,11,13         |

All other indices are enabled and execute in each positive profile. The masks
are independent literal expectations, never action guards. The following exact
dispatch lists cover both salts independently; only argument salts vary as above.

| Index | Computed Early   | Computed Late    | Written Early    | Written Late     |
| ----- | ---------------- | ---------------- | ---------------- | ---------------- |
| 1     | Trust0           | Trust0           | Trust0           | Trust0           |
| 2     | Connect0         | Connect0         | Connect0         | Connect0         |
| 3     | RequestNil       | RequestNil       | RequestNil       | RequestNil       |
| 4     | CrashFirst       | CrashFirst       | PersistFirst     | PersistFirst     |
| 5     | RestartFirst     | RestartFirst     | CrashFirst       | CrashFirst       |
| 6     | ConnectUntrusted | ConnectUntrusted | RestartFirst     | RestartFirst     |
| 7     | TrustAgain       | TrustAgain       | ConnectUntrusted | ConnectUntrusted |
| 8     | ConnectAgain     | ConnectAgain     | TrustAgain       | TrustAgain       |
| 9     | RetryNil         | RetryNil         | ConnectAgain     | ConnectAgain     |
| 10    | PersistRetry     | PersistRetry     | RetryNil         | RetryNil         |
| 11    | ExposeNil        | ExposeNil        | PersistRetry     | PersistRetry     |
| 12    | ConflictA        | ConflictA        | ExposeNil        | ExposeNil        |
| 13    | RequestB         | RequestB         | ConflictA        | ConflictA        |
| 14    | PersistB         | PersistB         | RequestB         | RequestB         |
| 15    | ExposeB          | ExposeB          | PersistB         | PersistB         |
| 16    | DeliverOld       | Recover          | ExposeB          | ExposeB          |
| 17    | Recover          | CrashSecond      | DeliverOld       | Recover          |
| 18    | CrashSecond      | RestartSecond    | Recover          | CrashSecond      |
| 19    | RestartSecond    | TrustFresh       | CrashSecond      | RestartSecond    |
| 20    | TrustFresh       | ConnectFresh     | RestartSecond    | TrustFresh       |
| 21    | ConnectFresh     | RequestA         | TrustFresh       | ConnectFresh     |
| 22    | RequestA         | PersistA         | ConnectFresh     | RequestA         |
| 23    | PersistA         | ExposeA          | RequestA         | PersistA         |
| 24    | ExposeA          | DeliverOld       | PersistA         | ExposeA          |
| 25    | DeliverFresh     | DeliverFresh     | ExposeA          | DeliverOld       |
| 26    | —                | —                | DeliverFresh     | DeliverFresh     |

Trust0/TrustAgain authenticate domain0; TrustFresh authenticates domain1. All
Connect names invoke `Connect`. RequestNil invokes `(0,1,Nil,firstSalt,TRUE)`;
RetryNil invokes `(0,1,Nil,retrySalt,TRUE)`; ConflictA invokes
`(0,1,A,retrySalt,TRUE)`; RequestB invokes `(0,2,B,retrySalt,TRUE)`; RequestA
invokes `(1,1,A,0,TRUE)`. All Persist names invoke `Persist`; all Expose names
invoke `Expose(TRUE)`. Both Crash and Restart calls are real original actions.
Recover invokes `AuthenticateRecovery`.

Written performs actual Persist before its first crash. Its RetryNil restores
the saved first salt in phase Persisted with reuse TRUE, and PersistRetry refuses.
Computed crashes before any initial Persist; its retry computes the alternate
salt in phase Computed with reuse FALSE, and PersistRetry really writes it.
ConnectUntrusted refuses before fresh trust. ConflictA is attempted after Nil
exposure in Idle with running/certain/trusted/connected TRUE and the matching
active domain/floor; its refusal exercises the payload conflict rule.

Actual ExposeNil and ExposeA capture the respective pre-action `pending` into
scheduler-only `nilSavedOld` and `nilSavedFresh`. Deliver consumes those actual
captures. The independent expected records never supply the delivery argument.
Old slot2 B really persists and returns. Recovery sets all three floors to1 and
revokes the session. The second crash temporarily clears knownFloor; Restart
recovers knownFloor1 from durableFloor1 before fresh domain1 trust and signing.

Late DeliverOld is legal at floor1: it delivers an already exposed network
record and creates no new return/enqueue. No consumer admission or generation
installation API is added. NoOldDomainExposure remains valid.

## Raw audits and complete witnesses

Every receipt contains actual enabled/executed flags and complete before/after
values for all21 original variables: running, trusted, connected, certain,
activeDomain, knownFloor, durableFloor, everFloor, durable, phase, pending, reuse,
restarted, actualRequest, crashRecord, writes, returned, network, delivered,
faults and event. Whole-record literal frames check changed and unchanged fields,
continuity, original Init and exact terminal records. Original helpers and sticky
fault journals are supplemental invariants only.

The normal config explores all eight finite schedules. Each
`witness-{computed,written}-salt{0,1}-{early,late}` config selects exactly one
profile and intentionally violates `NilCompleteNotReached` only at that profile's
full terminal. One existential witness cannot substitute for another profile.
Full terminals require both crash/restart pairs, the actual replay/computation
distinction, all refusals and intermediate writes/returns, durable floor recovery,
fresh signing and both selected identity deliveries.

`missing-delivery` suppresses only DeliverOld after recording it enabled. It
preserves all floors, durable records, writes, returns and network records, but
delivered contains only fresh A. Its PASS absence of the mode-qualified full
terminal is vacuous without progress evidence and gets no progress credit.
Each of eight `partial-*` configs separately reaches the exact end-index partial
history via the intended `NilPartialNotReached` violation. These are omission
and history-loss controls, not safety failures or source-fault kills.

## Actual-source fault and restoration contract

The unique target is actual Request's `pending' = IF reuse' THEN durable[d]`.
Replace only that assignment's `durable[d]` with `Record(d,s,p,salt)` in a private
copy. Every correctness switch remains TRUE. Each Written retry then produces
the caller's alternate signature bytes, despite an unchanged saved durable Nil.
`NilRetryByteAudit` fails immediately after RetryNil, before Expose. The four
`replay-audit-written-*` configs contain only that dedicated invariant, preventing
a generic raw or inherited replay invariant from intercepting the intended error.

The shared sensitivity workload is exactly
`signer-nil-replay-replay-audit-written-salt0-early.cfg`. The other Written
profiles are author products measured separately. All four Computed histories
must still reach their complete positive witnesses under this mutant; these are
successful controls and do not increase the kill count. Require all eight full
histories on the baseline copy and again after restoring that same private copy.
Hashes, exact raw failure, commands and restoration evidence belong to runtime
artifacts. Phase A freezes design only and claims no engine result.

Concrete FilePV/HSM persistence, WAL/supervisor behavior, power loss, concurrent
key owners, actual cryptographic signatures and authenticated app implementation
remain unproved. appReply TRUE and serialized ownership are premises. There is
no MarkUncertain repair; broader C01 stays open. Setup/parse/type failures,
timeouts and wrong invariant names are inconclusive, never witnesses or kills.
