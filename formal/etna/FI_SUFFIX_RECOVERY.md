# H04: partially settled FI suffix, recovery and actual replacement

`EtnaFISuffixRecovery.tla` adds a finite scheduler and raw observer over unchanged
`EtnaForcedInclusion` (M06). Its initial state is exactly `FIInit` plus three local
variables. It bypasses Setup, preserves `stage=0`, and wraps each actual `Produce`
with the same `produces<MaxProduces` guard and increment used by `AllFIActions`.
No block, fee, proof, recovery or landing decision engine is duplicated.

Canonical SPEC authority remains commit
`d18357214fab30ea512ae9858a11699806d72ba1`, blob
`649548c58d6629dd85143b33efd3644a3bb71509`. The reviewed workspace correspondence
is separately scoped; historical consumer pins remain unchanged. New shared
SignalService deployment/provider acceptance D01 remains WAITING and is outside
this companion. Relevant rules are FI-7.1-1/4/5, FI-7.2-1/2/5/13,
PROOF-6.2-24, RECOV-8-43..48/56..58, RECOV-8.4-11/12/13, and ACCEPTANCE 5 and
1.3/1.5. See [M06](FORCED_INCLUSION.md) for its original interface boundaries.

## Omitted chronology and finite program

The old FI profiles have `MaxProduces=2` across generations. They cannot construct
two old blocks, settle only the first, recover, produce a replacement for the
second and land it. This companion uses Fee A/B, `MaxHeight=2`, `MaxProduces=3`,
`MaxGeneration=1`, `MaxNonce=2`, `MaxTime=4`, `QueueBound=2`, correct build context,
and all original correctness options TRUE. It preserves the original symbolic
transaction/STF abstraction and introduces no capacity or cryptographic claim.

| Calls | Actual input and transition                                                                                                                                                                                              |
| ----- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 1–4   | Enqueue A at time 0; tick to 1, closing anchor 0; Produce(0,First,TRUE) consumes A at old height 1; enqueue B at time 1 with local cursor 1 but L1 head 0, charging 2.                                                   |
| 5–7   | Tick to 2 and 3, closing anchor 2; Produce(2,First,TRUE) consumes B at old height 2. B is included as the original symbolic B body token; this schedule does not invoke Completed/ObserveBuild or execute an EVM revert. |
| 8–9   | FIPrepare(2) captures the old two-height proof; FIFresh(1) settles only checkpoint 1 and FI head 1 while local cursor/frontier remain 2.                                                                                 |
| 10–11 | Authorize deadline 4; actual FIRecover at time 3 preserves settled checkpoint/head 1 and rewinds local cursor/frontier to 1. Blank profile passes {1}, changing only B's hash; Retain passes {}.                         |
| 12    | Attempt the queued old proof against the recovered state. It is refused. Its parent 0 is below new start 1, and FI cut checks can also reject it: this is not an isolated proof-generation test.                         |
| 13–15 | Tick to 4 closes recovery anchor 3; actual Produce(3,Skip,TRUE) in Blank or Produce(3,First,TRUE) in Retain creates generation-1 height 2 from retained parent (0,1); actual FIFresh(2) lands the replacement.           |

Blank and Retain are separate positive profiles. There is no free action
interleaving or fairness assertion. Every scheduled call uses the original action
when enabled, including bad operations introduced in private source-fault copies.
An actual refused call records unchanged raw state and advances the script; a
required refusal cannot become successful progress merely by advancing its index.

## Raw receipts and positive terminal

Each call records all original settlement variables, complete FI state, production
count and stage before and after, actual inherited-action enabledness, and actual
execution. Independent literal entries/blocks and milestone audits require the
old height-2 write before recovery, partial landing, recovery write, retained
parent and real replacement production/landing. The original recovery observer's
`oldCursor` field denotes the settled cut; the companion additionally captures the
actual pre-recovery local cursor 2 and verifies its write to 1.

The complete terminal requires all 15 receipts, with only the old-proof attempt
refused: three actual productions, one actual recovery and two accepted landings.
Old (0,2) and replacement (1,2) block histories remain distinct; both use parent
(0,1), and the new generation begins at retained cut 1. Final checkpoint, FI head,
local cursor, frontier and tail are 2. Admissions charge 1 then 2 despite B's local
cursor already being 1; revenue remains 3 throughout recovery. A's timestamp/block
remain 10/0, B's remain 12/1, including blanking. Indices 0/1 are each applied
exactly once on L1, index 2 never. Normal profiles retain original settlement and
FI safety assertions in addition to independent raw/milestone/terminal audits.

## Profiles and falsification controls

- `fi-suffix-recovery-normal`: both histories and all original/applicable audits.
- `fi-suffix-recovery-witness-blank` and `...-retain`: each must violate only
  `SuffixTerminalNotReached` after the complete positive history.
- `fi-suffix-recovery-audit-cursor` and `...-hash`: focused normal PASS profiles
  selecting only the respective raw recovery-write audit. These alone make no
  progress claim; positive profiles separately establish their complete context.
- Fourteen `fi-suffix-recovery-missing-*` controls each suppress one necessary
  action, across both histories. Each must exhaustively PASS only
  `SuffixTerminalNotReached`. This demonstrates loss of the complete witness,
  not safety or a successful recovery.

Two actual-source sensitivity trials target private `EtnaForcedInclusion` copies:
replace the recovery cursor write with retention of the old local cursor, or omit
the actual hash-only queue blanking. The real bad recovery must execute before
`SuffixCursorAudit` or `SuffixHashAudit` rejects its raw write. Dedicated configs
exclude generic original safety invariants, preventing a type or unrelated safety
failure from masquerading as the intended kill. Original, mutated and actual
same-copy-restored executions and input hashes are required. These are deliberately
injected source faults, not actual protocol findings.

This guide describes intended checks before the first execution snapshot. Actual
outcomes, immutable source/config/tool hashes, raw log paths and independent review
and behavioral challenge results are recorded by the root in the evidence report.
A witness violation is an existential bounded trace, not a liveness theorem.

## Reflection and remaining premises

The strongest plausible false green is a scheduler that calls recovery without
first producing the discarded suffix, or counts a prepared/enabled replacement
without executing and landing it. Complete literal receipts, three counted actual
productions, two actual landings, focused bad-write audits and required-action
omissions are designed to distinguish that failure. Independent verification must
choose its own additional fault or missing-action control from the original source.

The newly exercised valid history is two old blocks, partial L1 settlement,
blank-or-retain recovery, retained old-generation parent, actual replacement and
once-only suffix landing. Symbolic bodies, abstract timestamps, fee units, valid
chain/STF, correct forced-inclusion resource interpretation, authenticated anchors
and atomic authorized recovery remain premises. This is no real STF execution,
fee-currency test, gas/blob/zk-budget test, message-processing scheduling
conformance, prover capacity or real proving result, client refinement, deployment
or shared-provider authentication result. The original Transient scheduling
abstraction remains unchanged. Implementation/resource/authentication proving and
D01 deployment/provider obligations remain OPEN/WAITING.
