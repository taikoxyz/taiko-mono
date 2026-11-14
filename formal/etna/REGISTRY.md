# M05: bounded registry principal and lifetime state

`EtnaRegistry.tla` models the registry lifecycle from Etna SPEC at
`d18357214fab30ea512ae9858a11699806d72ba1`. It is a finite model of the
written rules, not a proof about a deployed Solidity implementation.

The model keeps issued bond identity separate from slot ownership. Bond 0 and
slot 0 are valid when their presence flags are set. An unissued bond is the
actual all-zero record, including `exit=0`; registration explicitly writes the
no-exit sentinel. A displaced bond keeps its principal, owner, pending top-up,
confirmation and liability. Its old slot number cannot authorize clearing a
replacement's slot at withdrawal.

## State and source boundary

| Model operation/state                                                                        | Source rules                   |
| -------------------------------------------------------------------------------------------- | ------------------------------ |
| Register, immutable issued/key identity, minimum balance slot and tie break                  | STAKE-4.1-4..14b               |
| Pending top-up, readiness and explicit activation before exit                                | STAKE-4.1-15..22               |
| Earlier-only exit, actual landed snapshot confirmation, first confirmation clock, withdrawal | STAKE-4.1-23..30               |
| Historical-generation evidence and whole remaining principal slashing                        | STAKE-4.1-31..35               |
| End-of-block immutable entries snapshots                                                     | STAKE-4.1-36; STOR-B-20..33    |
| Initialization from a nonempty past selection snapshot                                       | START-10-5; STAKE-4.1-38       |
| One-time fixed-rate forfeiture, effective-first deduction, forced exit                       | FORF-4.4-1..20                 |
| One ordinary recovery with an issued excluded bond                                           | RECOV-8-40a..42; 8.3 atomicity |

Each contract call is atomic. Invalid registration is represented as a rejected
call and must not issue an id or consume a key. Other rejected calls are disabled
transitions, equivalent to atomic reversion for the modeled state. Registration
keys are independently chosen from the finite unused-key domain. There is one
modeled owner (caller 1); caller 2 can perform a zero-balance public withdrawal.
Ownership transfer, multiple owner addresses and arbitrary withdrawal recipients
are not modeled.

`Tick` closes the current L1 block before advancing time. Its stored entry
snapshot is separate from an independently captured raw entry observation.
Initialization and later selection accept only closed snapshots strictly before
the current block. The actual active member set and powers come from that
immutable snapshot. Eligibility requires positive effective stake and
`activeFrom <= snapshot < exitEffective`; pending principal adds no power.
Selection retains every eligible entry (`n_max=SlotCount`), with normalized
minimum stake and voting-power unit 1. Full selection caps, concentration limits,
key sorting, roots, encodings and M04's H+2 schedule are not re-proved here.
A valid normal-settlement snapshot/power interface is assumed; the model does
not form a product with M04.

The active snapshot never decreases in this scope. Ordinary recovery changes
the generation and can move an excluded bond's exit earlier; it does not erase
principal or lifetime flags. Verifier-failure rollback and its confirmation
revalidation are a separate M09 scope. A slashed, forfeited or displaced bond may
still appear with its previously assigned voting power until a new selection
lands. Only withdrawal is forbidden while that bond remains in the actual
active set; the model does not invent an immediate power-removal rule.

Cryptographic key canonicalization, registration PoP, deployment-domain binding,
valid historical double-sign evidence, authorized matching-key DAO forfeiture
and unexpired authorization are explicit input premises. There is no modeled
forfeiture authorization queue, timestamp or expiry mechanism. ERC20 transfers,
non-reentrancy and whole-call reversion are premises. Integer overflow, packed
width limits, exact production token denominations and production basis-point
arithmetic are outside this small arithmetic model.

## Exhaustive profiles and workload limits

All selected action types remain in `AllActions`. Time, issued identities and
accepted top-up calls are bounded explicitly; there is no trace-length constraint.
`MaxTopupCallsPerId` is an external workload limit, not a registry rule.

| Configuration            | Checked finite workload                                                                            |
| ------------------------ | -------------------------------------------------------------------------------------------------- |
| `registry-workflow`      | One slot, two issuable ids, blocks 1..6, one top-up per id, registration amounts 1/3, top-up 1     |
| `registry-two-slot`      | Two slots, three issuable ids, blocks 1..4, one top-up per id, registration amounts 1/3, top-up 1  |
| `registry-repeat-topup`  | One slot/id, blocks 1..4, two top-ups, registration/top-up amount 1                                |
| `registry-split-pending` | One slot/id, blocks 1..4, top-up 2; half forfeiture reaches effective-first then pending deduction |
| `registry-all-forfeit`   | Same small numeric profile, 100% forfeiture; pending reaches zero and ready block clears           |

The workflow profile's declared `PreparedWorkflow` drives real operations:
register bond 0 for 1 at block 1; tick to 2; top up by 1; tick to 3; initialize
from the closed block-2 snapshot where bond 0 was active; register bond 1 for 3,
displacing bond 0. Every intermediate prefix state is checked. After the prefix,
every selected action is available subject to its ordinary rules and finite
bounds. `FixedRegistrationBlocks` separately limits external calls to block
`1 + 2*nextId`; this condition is outside `CanRegister`, so an out-of-schedule
call is not presented as a protocol rejection.

The two-slot prepared prefix instead registers ids 0 and 1 for 1 in block 1,
closes blocks 1 and 2, initializes from block 2 with both members, and ticks to 4.
All actions then run at block 4, including a third independently keyed
registration that exercises minimum-slot admission and the lowest-slot tie.
This profile checks a finite admission and accounting workload; it cannot
complete a new withdrawal after that prefix. The one-slot workflow checks the
full active-member retirement and withdrawal path.

The repeat-top-up and numeric profiles start from raw empty storage without a
prepared prefix. Repeated activation is therefore checked in its own workload;
the main one-top-up profile does not cover arbitrarily many top-up cycles.
Forfeiture uses `ceil(balance / ForfeitDenominator)`: denominator 2 represents a
normalized 50% rate and denominator 1 represents 100%. Slash bounty is zero and
all slashed principal goes to the sink. Other production rates, nonzero bounties,
larger amounts, more identities/slots and arbitrary workload timing remain
outside these exhausted profiles.

## Assertions and counterexample controls

The observation-only `audit` record never enables an action. It records accepted
caller deposits, actual payouts/sinks, issued keys, first confirmation times,
principal allocation and raw snapshots independently of mutable contract fields.
Receipt assertions tie real registration decisions to raw slot balances and
caller inputs, real displaced records to their prior full records, and real
withdrawal slot writes to their previous owners. Forfeiture checks use an
independent ceiling inequality and actual post-deduction effective/pending fields.

Normal profiles check atomic rejection of every operational state write, cleared
withdrawn records, external and per-bond cash conservation, custody backing, effective and
pending allocation, issued/key permanence, untouched default ids, slot inverses,
old-bond withdrawal preserving replacements, permanent forfeiture flags,
earlier-only exits, idempotent confirmation clocks, delayed authorized
withdrawal, immutable snapshots, actual committee identities/powers, and absence
of withdrawn bonds from the active set.

Negative controls deliberately omit a guard or corrupt a write. Each must fail
its exact independent invariant: wrong admission slot, unissued confirmation,
activation after exit, confirmation without snapshot coverage, early withdrawal,
postponed confirmation, forgotten lifetime key/forfeit flags, clearing a
replacement's slot, duplicate payment, pending principal included in a snapshot,
wrong stored deposit, rejected registration consuming a key or shadow-marking a
funded displaced nonmember as withdrawn, and pending-first
forfeiture deduction. These are model-sensitivity checks, not protocol findings.

Reachability cases deliberately negate specific witnesses. They must find an
issued bond-0/slot-0 withdrawal after pending-funded displacement; a withdrawal
of a member that really appeared in the initialized active set; readiness
equality activation; exact snapshot/exit confirmation equality; two explicit
top-up/activation cycles; and partial forfeiture followed by historical-generation
slashing and public zero-balance withdrawal with lifetime flags preserved.
The confirmation-equality witness uses two slots so another member keeps the
exact exit-height selection nonempty. Finding a witness does not exhaust its
whole profile or establish liveness.

## Incomplete wider experiments

Initial raw-initialization one-slot/two-id/time-6 exploration and a version with
fixed external registration blocks both exceeded the 45-second case limit.
Unprepared two-slot/two-id/time-4 exploration also exceeded that limit. A later
two-slot/three-id prepared trial retaining full rejected-call history timed out;
the final model instead records an independent bad-decision flag for rejected
calls and retains full accepted registration/displacement receipts. Operational
actions and guards were unchanged by that observation-only compaction. These runs
remain **INCONCLUSIVE**, with reproducible archived inputs outside the default
configuration suite under `experiments/registry-*`. They are not passing default
cases. Their observed progress and exact input hashes are recorded with those
artifacts. No final queue-zero claim is made for a timeout.

The source-valid prefixes above narrow external workloads to make a meaningful
scope exhaustive. They do not establish equivalence to the wider incomplete
products, whole-protocol correctness, unconditional liveness or implementation
conformance. Run the default cases through the shared `check.py` harness as
explained in the main Etna README; the harness checks exact outcomes and input
hashes, and downloads nothing.

A second adversarial pass found a narrower observer gap after rejection-history
compaction: a rejected call could shadow-mark a funded displaced nonmember as
withdrawn while the main normal profile's prior assertions still passed. This
was a deliberate model mutation, not a source-permitted protocol behavior. The
model now observes actual complete operational post-state equality (`r'=r`) on
every rejected registration and independently asserts that any withdrawn record
is issued, has zero principal/owner/confirmation/readiness and holds no slot.
The historical probe checked the main normal profile; no claim is made that it
escaped the entire previous control matrix.

## Validation of this candidate

The implementer ran all 26 default M05 cases through the shared harness on
module SHA-256
`0a659bb1deafa2dff19bbde70dfa057dd650daa36328871ef0084a3080cc3b44`.
All exact expectations passed: five normal exhaustive profiles, fifteen deliberate
missing-guard/write controls and six reachability witnesses. Normal runs ended
with queue zero; controls/witnesses returned invariant exit 12 at their declared
property. A witness's nonzero queued remainder is not an exhaustive search.

| Normal profile           | Generated | Distinct | Final queue |
| ------------------------ | --------: | -------: | ----------: |
| `registry-all-forfeit`   |     1,955 |      595 |           0 |
| `registry-repeat-topup`  |     3,534 |    1,084 |           0 |
| `registry-split-pending` |     2,554 |      788 |           0 |
| `registry-two-slot`      |   934,608 |   82,391 |           0 |
| `registry-workflow`      |   236,666 |   44,110 |           0 |

Independent adversarial review and independent behavioral verification are
required before integration; their final verdicts and the repository-wide
regression result are recorded by the task owner in the main report. These
finite results do not remove the assumptions and incomplete products above.
