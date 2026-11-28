# Anchor/proof/recovery source and model interface

This is a newly authorized source178 product at formal baseline f5ca696e1.
The two independent literal JSON fixtures and their source report were frozen
before the product implementation. They provide expected values, never action
guards. This contract qualifies every normal and adversarial input family.

## Authority and independent values

Draft178/base360, SPEC SHA256cae2e783a06b81b36dd0d412d678c67f764b6d96143c676aec99df8008eee7e0.
See draft_rules/anchor_proof_source.json and the three unchanged fixture copies.
Key clauses: CONS3.3/3.4,COMM4.3,LAND6.1,PROOF6.2,BATCH6.3,BACKP6.4,
RECOV8/8.1/8.4,SYNC9-3/5/6a. Root read relevant clauses and the independent
source audit; old runtime classifications and old model statuses are untouched.

The normal main fixture is an explicitly conditioned large history: actual
settlement advances independently of local replay, the adopted anchor can lag,
both short and long proofs are captured before either lands, FI advances0/1/2,
and actual-c slot285 parents change10/12/13. Its recovery-at14 requires the
specified outage and audited last-provable14 premise. Retained candidates keep
their original timestamps, roots and M/F. Initial H11/A was prepared when A was
the local finalized view; it is not a fresh first-generation selection of A
after the node has already learned B.

The complete micro alphabet has two immutable sound jobs s10→11/l10→12,
reference450, and two inclusion slots500/600 with three offers each
(idle,s,l). All nine offer combinations are enumerated in the supplement.
They coexist with independent local observation/replay/EL/Comet comparisons.
Remote certificates/proofs may exist and land while this node is still at10.

The p-only positive family retains p12's authenticated B320/Disabled/F, uses
fresh ordinary V141100 with M3Q for new H13/H14, reference141200 and
inclusion141300. B ancestry distance140880 is beyond the supported131072
budget, while V's distance100 fits. H13 signs with p12.next=Stake; H14 signs
with p12's own B-derived F, not V's policy. H13 then selects Stake for15.
Both FI entries are due and must be consumed in exact transaction0 order.

The alpha/beta cut fixture supplies two independently certified/guest-accepted
histories under the explicit >1/3 double-sign premise. It is not a nominal
honest-quorum path, not a synthesized certificate and not a deployed defect.
Both share EL at11, but distinct Comet identities force full-cut rejection
after alpha lands. Do not make guest validity depend on today's c: that would
hide the consumer-boundary fault this fixture checks.

## Canonical implementation interface

New module EtnaAnchorProofRecovery. Constants Scenario and Fault. Scenario is
one of Micro,Main,Twin,POnly. Fault is one of None,LatestC,ElOnlyCut,
LatestOriginF,DropPending. Normal configs bind None. Fault configs are explicit
verification sensitivity controls. No production implementation changes.

Variables s,receipt,cursor. s holds every operational field. cursor is only the
external test-driver position, fixed0 in Micro. The old receipt cannot enable
any transition. Init/Next/Spec are the public entry points. All named profiles
share one dispatch and actual transition implementations.

Micro Next nondeterministically offers the complete declared finite alphabet,
including both inclusion slots and independent node events. Main/Twin/POnly
use named external input sequences for existential conditional histories;
cursor advances on a consumed offer even when the operation is refused.
Endpoint predicates cannot gate actions. Neither the larger sequence runs nor
their generation1 behavior discharge an unrestricted safety graph.

Keep source-selected signed block/cut/EL-state identities immutable, with an
independent fixture table for each family. The symbolic sound guest/STF/QC
contract is explicit. Model effects, committee choices, proof binding, actual
Inbox reads, suffix accounting, local trust and recovery using operational
state, not expected endpoint records. A block proposed under stale B at14
must remain offerable as a pressure-refusal input. A different proof starting
at13 is different from trimming an already captured12→14 job.

s must separately expose actual l1, immutable l1 history, node and immutable
jobs. l1 includes number/generation/c/FI head+tail/M/F/nonce/records/origins/
SignalService. Each checkpoint record carries height,parent,generation,EL,
Comet,FI and saved EL-state identity. node exposes generation/fixed origin,
local committed tip and state, own finalized view, known target, comparison
stage, matched height, trust, retained candidate and pending committee state.
jobs expose captured p,h,generation/origin,reference,full blocks/data/cuts and
statement identity/completion. Author freezes the concrete nested field schema
in the report before root's RED execution and independent raw-reader binding.

Required safety names: TypeOK,AnchorFenceSafe,ActualCutSafe,LandingStateSafe,
ProofBindingSafe,CommitteeAnchorSafe,SignerTrustSafe,OriginFallbackSafe,
RecoveryStateSafe,FrameSafe. Invariants recompute source constraints from
actual receipt before/input and actual successor; never call the same faulty
admission helper or compare with a producer-populated expected result.

Required observation names are the planned NoPressureRefusal,NoOverlap,
NoDirectLong,NoRetained,NoPendingTrust,NoRecovered,NoNewDomainLanded,
NoOriginFrozen,NoAncestryBudget,NoPOnlyWitness. They inspect concrete fields
and actual receipts, not a stored milestone that also authorizes an operation.
If a view omits receipts, retain the actual safety and observation truth bits
as well as all operative s and cursor, with a same-state/input argument.

Pure old helpers may be instantiated with explicit unused-variable bindings;
only Choice/OriginChoice/Decision/Quorum/Updates are candidates. No historical
Next/Commit/Land/Recover, frozen activeSnapshot writer or narrowed header-
membership shortcut is reusable as an operational action.

## Root RED/GREEN and failure boundaries

First coherent scaffold deliberately misuses actual c in the NORMAL Fault=None
pressure guard. Root requires actual AnchorFenceSafe
failure after a valid prefix with actual12/adoptedB.c10/local13, attempting14/B.
The same Main/None configuration and input sequence is run before and after
the normal guard repair; keep the permanent LatestC mutant separate. No correct
normal pressure guard before the observed RED. Parsing/setup
failures are not RED. Then Fault=None must produce a real refusal and reach
the valid C-anchored neighbour. Other controls differ in the declared semantic
fault alone and require original/result/restored packet hashes.

Root gives engine GO only for reviewed immutable packets in the existing
offline sandbox. No dependency installs, host imports, Git/secrets mounts,
network, signing, node/EL/Go execution or production/SPEC/Notion changes.
Use existing TLC45s/512MiB/one worker/seed1. A timeout stays INCONCLUSIVE and
out of the normal default bank. All bounds and conditional premises remain
visible in the report; old Free and runtime obligations stay OPEN.

## Binding refinements from independent builder review

1. Build historical snapshots from actual branch-local protocol writes. Identity
   includes number, parent identity and storage/input/outcome projection. A
   lookup by number selects only that run's corresponding record, never the
   universal short-first J/L fixture. All reads and ancestry pointers refer to
   that immutable identity. Shared prefixes alone may reuse an identity.
2. Main selects an immutable source-derived script ID at Init, retained in s
   and VIEW, or an equivalent explicit prefix tree. Short-first/direct-long
   must remain distinct selectable source-valid input scripts. This identifier
   is an external driver choice, not a milestone that enables protocol actions.
3. Expose actual L1 slot attempts/outcomes as immutable history metadata. Nine
   private Micro probes query the two exact offered inputs and outcomes plus
   per-slot records/SignalService. Probe wrappers extend the actual product
   with observation only; they do not alter dispatch. Preserve the queried
   observation bit in the private VIEW if receipt merging could hide it. Root
   compares all nine paths with the literal table, including second-slot idle
   and range refusals, plus the remote-first/pending/retained paths. A genuine
   deleted stale-offer branch must fail this coverage, not merely static parsing.
4. Frame checks compare contract storage and local state separately from L1
   number/history and consumed input position. Refused inclusion at500/600
   advances the external slot without protocol writes. Stale recovery at1000
   preserves c/generation/nonce and leaves fresh R141000 as a distinct input.
5. Scope SignerTrustSafe to admission/status against known finalized target and
   complete match. Gate probes do not model a Comet refusal. Any real refusal
   followed by resumed signing needs a separately explicit bound restart/session
   premise. No end-to-end signing transport or replay proof is claimed here.
6. Do not count old P/short/long rejection after R as isolated generation
   sensitivity: all also fail range/reference. This remains an explicit OPEN
   consumer-boundary item unless a reviewed one-field interface packet becomes
   available. Keep the valid new-domain p14 record-reuse path as positive evidence.

## Implemented interfaces after independent model review

The initial contract above remains the frozen preimplementation requirement.
The reviewed product additionally exposes lastEL separately from record285 and
node.pin/targetEL separately from latest own finality. An unchanged checkpoint
and generation retain the pending comparison pin; newly available contradicting
EL closes trust before a record285 reply. That reply checks both local hashes.
Each covered current/next membership is bound, including terminal and origin
boundaries. All ordinary read roles in this restricted alphabet use the actual
reference queried; p-only M/F authority remains separate.

Slot285 root/ledger values are saved ghost projections of authenticated EL,
not storage words. The recovery consumer accepts an independently supplied
archive EL/root/ledger identity and explicit state/origin/genesis/session
success contracts, then compares against lastCheckpoint and SignalService.
Real crypto, archives and guarded runtime establishment remain external.
The diagnostic captured auth stays at c12; the fresh call's complete tuple is
a pinned internal input recipe. Raw receipts expose its tag, inclusion slot,
actual prestate and effects, not the complete payload as separate words.

Private ordered-history probes may add a deterministic observational variable
probe. Original Micro Next, guards, inputs and the three operative variables
are unchanged, and cursor remains0. The observer cannot enable actions. Private
views retain it; independent readers allow it only for the two declared probe
modes and still verify actual receipts/states. Other traces retain exactly the
three-variable schema. Conditional boundary-input scripts use actual Take and
Dispatch; their malformed packets do not claim valid crypto/guest acceptance.

## Scope of Main identity literals

The frozen model comment at lines 54–56 and the independent fixture tables
use the branch-local identity convention for dependent Main inputs. The old
signed H14 may be shared while its L1 checkpoint parent differs. The two Z
snapshots have different occupied checkpoint records. Their carried witnesses,
dependent H15–H17 block/header/root identities, reference IDs and new proof
objects must be interpreted in the selected history. Blob or other content
with equal preimages may share an interpretation. Proof validity and routing
claims here cover one immutable script and its own jobs. Cross-history replay
or a construction of concrete commitments requires separate evidence.
[Finite lifting argument and typed evidence](anchor_proof/MAIN_IDENTITIES.md).
