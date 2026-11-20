# Etna boundary compositions design

## Intent and authorization

The user authorized a new group of seven with “没问题?那继续”, retaining the
previous seven-item cadence and independent verification workflow. This is a
new Y01–Y07 batch based on `9abe2590805787569c0aaf6fb528db367482fffb`, not a
restart of W01–W07 or any older completed group. Complete these seven and their
final review/publication gates, then return to feedback-only monitoring.

The purpose is to challenge missing protocol histories and real stock interfaces.
A clean selected result is not a protocol-completeness percentage. An independently
supported natural protocol/source defect goes back to the user with concrete
evidence; defects in verification code are repaired within the authorized scope.

## Sources and evidence classes

Current main is `479bc3db6b5341b72b6e7b9233be5b53d64a574a`. Its exact SPEC,
ACCEPTANCE and SWITCH streams match reviewed bundle
`2e6763e21bc236cfcda6011d164b32040f9e0c8d`. The draft's own documents remain
historical; current-only claims need the separate exact workspace or effective
merge. Preserve every existing bundle and claim row.

CometBFT remains pinned at `0880b4d378f347ab16e54ec677ff50d803f37d62`.
The only allowed vote corpus is the reviewed public projection SHA-256
`34932f8ddf991ae41eb1be94c873e99524f51cf96d427faed4a1bfc443dc960e`.
Historical Solidity is the existing contracts manifest, including the Registry
SHA-256 `25b114975525269ee3f0bd3dfcc40d8480faa0df125c3b39da3ec27ca3dec8f1`.
Its displaced-slot admission is not current empty-slot admission. Unchanged
forfeiture/storage operations may provide a separately labeled component replay.

Keep four outcomes separate: source correspondence, mathematical/model checks,
actual pinned API execution, and missing end-to-end or deployment acceptance.
Source selection always remains `NOT_EVALUATED` for execution. A synthetic block
or opaque signed parent ID does not become an authenticated import package.

## Approaches and coordinator choices

1. Raising the old timeout or replacing the old domain with a smaller graph would
   not address the missing reasoning. Retain the original inconclusive runs.
2. Full client/EL/guest/import execution is desirable, but the concrete interfaces
   and authenticated histories are not available here. Keep those requirements
   WAITING, without fabricating replacements or resuming separate paused work.
3. Chosen: one same-domain safety projection, three new protocol compositions,
   a funded Registry component and two stock Comet lanes, with exact source/receipt
   boundaries across all seven.
   The funding composition includes an actual historical Registry component.

The coordinator chose the concrete cases below under the user's continuation
authorization. The tradeoffs are bounded domains, explicit authentication/proving
premises, and maintenance of versioned model oracles. No design approval round is
added to the established autonomous workflow.

## Seven deliverables

### Y01: same-domain timestamp safety projection

Preserve the W07 StructuralSafety constants MaxL1=5, MaxHeight=4,
MaxProduces=4, MaxWrites=1, every offered call, and Frames/Typed/Prefix/
ScheduleDispatch. Add a separate wrapper/config that fingerprints `(s,bad)`.
Prove by source-bound read/write dependencies that old `last` is overwritten and
old `seen` affects only its own observations. Each projected edge lifts to an
original Call from any representative; reconstruct `last'` and `seen'` exactly.
Primed receipt queries in ScheduleDispatch must remain observable.

Review the argument independently and compare original/projected small-profile
outcomes plus actual refused-event/frame source controls. Keep `bad` in the view.
Never prune calls before their admission/frame/event checks. The original
unviewed timeout stays INCONCLUSIVE; a completed quotient gives only the stated
same-domain safety argument, not liveness or all-label trace enumeration.

This task also extends the authoritative current claim inventory once with seven
fixed `boundary-products` claims. Old rows and bundle pins remain identical.
A shared attribution helper delegates to current_spec rather than copying it.

### Y02: repeated recovery at the same nonzero checkpoint

Model generations 0,1,2 at one previously settled c=6>S, outside the special
Unzen first-landing boundary. Preserve each generation's immutable
origin, exact external authorization, nonce and actual execution R. First recover
with rules=0; produce but do not land a g1 block; second recover with nonzero rules.
The selected R1 has number32/time101 and R2 number35/time104. R1 finality cannot
release g2 before R2 finality. The g1 suffix/job survives only in external archived
evidence; the live g2 head and canonical state reset to c. Its first block has
genesis BFT time104, empty LastBlockID/LastCommit and a finalized own anchor at or
above R2. Preserve all origin records and generation-specific chain domains.
Complete fresh g2 landing,
finalized checkpoint observation, and a further Produce using that checkpoint.

Isolate same-generation nonce invalidation from generation mismatch. Keep old
authorization bytes as actual attempted inputs, not rewritten from current PRE.
Use an origin-overwrite fault and an actual second-bootstrap/observe omission.
EL validity, finalized L1 authentication and empty-list premises remain explicit.

### Y03: ordered rule changes, pause and whole-range settlement

Within one generation, perform two actual ScheduleRules writes and produce four
blocks with EL times3599/3600/3601/5184 and ordered rule history `0,1,1,2`.
M=1296, writes2304→3600 and3888→5184, and anchors3456/3456/3600/5184 form the
concrete legal clock. A valid prior settled parent is at3598. The attempted first
rule1 block at3600 waits while software supports only0, preserving every live
field. Resume with the retained/finalized historical anchor3456 after installing
rule1 support. The following block's BFT3600 and anchor3600 make literal
max(parent3600+1,BFT3600,anchor3600)=3601; a multiplication of the integer-second
successor law is not an admissible reduction. Use legal historical anchors, exact
BFT/EL times, headroom for four unsettled blocks, and a lossless unsupported-rule
pause followed by resumed production. Capture and settle the original full range.

Each proof family must bind every block's own ordered rule interpretation.
Each family's ability to aggregate adjacent-image segments into that whole-range
statement is an explicit proving premise, not established by taking a flat union
of image capabilities. Endpoint-only checks, the union of the two families'
capabilities, and latest-slot
reinterpretation of historical anchors are independent negative controls. A
concrete ELF need only support its declared adjacent forks; no three-fork ELF or
actual proof generation is assumed. Guest internals and aggregation choices stay
outside protocol verification. Actual shared client/EL/guest upgrade vectors,
FI singleton execution and the special Unzen switch remain WAITING.

### Y04: funded pending-only forfeiture and withdrawal

Use the actual historical Registry proxy/public PoP fixture with a closed test
allocation of 15 tokens: owner A9, owner B4, public/treasury2. Register A/B at4,
authorize forfeiture, then A deposits its remaining5 as pending. At the deadline,
ceil((4+5)/2)=5 leaves eff0/pending4 with its readiness retained and sink credited5.
After an explicit mocked covering snapshot, actual Registry confirmation and its
block-number delay, public withdrawal refuses while the owner receives exactly4.
The authorization's exact calldata/executor is retained before the top-up.
Check deadline+1 in timestamp seconds and a funded non-owner topUp1 on separate
intact-prefix branches. The native Inbox premise has only synthetic snapshot and
generation setters, not Land or recoveryNonce; changing that generation is not
actual recovery/nonce execution. Reuse A's real payout4 with a fresh A-owned
public PoP and approval only, never another mint, and check permanent flags.

Derive an independent full account/storage/call/event journal. Change actual
pending-debit arithmetic in the primary source control; independently change the
withdrawal ownership or strict-deadline guard. Original/restored source and
receipts must match. The token is a fixture with a closed allocation, not a real
TAIKO deployment or proof of economic funding; admission/current Registry and
actual governance recovery remain outside this component's native claim.

### Y05: positional registry snapshots and R-derived selection

Consume authenticated width as an input, not occupied cardinality. With width2,
withdraw slot0 while slot1 survives; compare hashed all-zero slot entry with raw
zero padding, positional leaf index, checkpoint packing and root. Do not choose
a trailing-empty trimming policy that the current text does not specify.

Compose lifetime bond identity and slot reuse with recovery exclusions and final
block-R selection. A withdrawn old bond remains issued and cannot target its new
occupant. Invalid/unissued/wrong-key list items reject the whole state. Activate
a matured top-up before versus after recover in the same R: both see the final
closed R state; R+1 activation cannot change R. Select by max(s_min,vp_unit),
set-key order and integer floor powers. Land consumes its actual terminal-active
snapshot, not a pending or later live set. The W02 symbolic `count` is not an ABI
width, and its selected all-slot properties remain valid within their abstraction.

Also use a separate static width3→four-leaf vector to exercise true raw-zero
padding. The operational width2 history alone cannot do so. s_min4/vp_unit2 are
symbolic units; concrete byte vectors may multiply by Q=10^23 (minStake4Q also
satisfies the deployment supply inequality), and need separately discriminating
eligibility, set-key tie and floor examples. n_max1 cannot satisfy the governance
dispersion check. This is an execution/list/selection component, not a full
authorized RECOV-8.1 recovery; that governance acceptance remains unverified.
Use explicit block-close at R7 and at R+1=8 so the final horizon can observe both.

Use exact byte encoding and a small operational model, with independent literal
entry/root/selection observations and wrong-count/slot-occupant/live-snapshot
source controls. Concrete L1 proof authentication and real node/guest committee
derivation remain WAITING K01; historical roots are labeled by their actual source.

### Y06: terminal seen-commit reconstruction and binding

Use genuine public h1000 A precommits, stock VerifyCommit, Store.Bootstrap,
BlockStore.SaveSeenCommit and consensus.NewState/GetRoundState, without starting
a signer/service. Exercise a synthetic successor through normal ValidateBlock.
No successor block is needed merely to reconstruct the terminal LastCommit.

A genuine same-height B commit can have valid signatures and quorum but mismatch
state.LastBlockID=A. Record what the constructor accepts, then independently
observe VerifyCommit(A) and normal successor rejection. A/B each get independently
reopened blockstores and fresh BlockExecutors/successors to avoid height-keyed
seen-commit and block-validation cache hits. Both successor headers bind parentA;
their LastCommit comes from the actually reconstructed votes. Add wrong-domain,
subthreshold and missing-commit cases with exact context and typed outcomes.
For missing/quorum/domain constructor cases, locally capture only the exact
source-declared panic type/reason at that invoked API. Assert both seen and
fallback block-commit stores empty in the missing case; any unexpected panic,
fixture failure or process crash remains INCONCLUSIVE.
This is a caller/import boundary, not a Comet vulnerability. The signed parent IDs
are opaque: no original matching parent block/partset exists in this corpus.
Do not claim a complete authenticated DATA-5.4 import or consensus-chain replay.

### Y07: evidence age, gossip and imported committed markers

Construct DuplicateVoteEvidence from public h1000 A/B precommits. Run stock
Pool.AddEvidence/Update/CheckEvidence/PendingEvidence and Reactor.AddPeer with a
controlled peer that observes real Send calls. Test +900/+901 block gossip and
strict dual-age expiration independently, then pending-holder versus cold-pool
acceptance, startup pruning and persistent committed markers. Check exact3600s
equality and both neighboring times independently of the block-age boundary.

Use historical block time for evidence age, exact state progression, and separate
cold pools because CheckEvidence itself writes pending state. Synchronize on
actual branch/Send observations; absence after a sleep is not a refusal proof.
NewPool prunes its DB at construction. Restart-prune and continuing-holder-prune
therefore use separate DB fixtures reconstructed from the same prefix or a
durably cloned branch point, with the exact latest state persisted for Load.
Assert the continuing holder retains its pending item before its own Update.
Install/reopen a window committed marker through stock APIs with w>1000 so the
candidate is strictly below (w,s]; assert no lookup at h<=w for that item, and
contrast an unmarked item with an actual missing-h1000 history lookup.
Source controls alter actual age/marker behavior and restore the same file.
Fake peer transport and synthetic blockstore context are explicit; real network
authentication, full original import history and atomic multi-store install stay
WAITING.

## Shared implementation contracts

Append fixed claims `timestamp-projection`, `repeated-recovery`,
`mixed-rule-landing`, `funded-forfeiture`, `registry-origin-selection`,
`terminal-seen-commit`, `evidence-lifecycle` under `boundary-products`.
`reviewed_boundary(workspace_root, fixed_claim_id)` requires exact current three
documents, delegates selection, and emits no success itself. Each actual producer
owns its fixed claim and verifies raw status/arguments/frames before attribution.

New Go consumers share one reviewed public-input reader. It hashes the actual
buffer before JSON decoding. Native drivers pin and validate the original public
bytes before staging, recheck the staged bytes before Go, and inventory all
staged source/tool/module files. Reject unknown/swap/mixed metadata at unchanged
native bytes. Closed schemas preserve integer/bool identity, duplicate-field
rejection and complete raw terms.

## Execution and acceptance

Only formal/test tooling, fixtures made exclusively from reviewed public data,
and associated reports are mutable. No production/SPEC/Notion/live changes,
dependency installation, private key or mixed-fixture access, fresh signing,
merge or mark-ready. Preserve all prior raw evidence, caches and source/configs.

Use the existing isolated draft worktree, managed Python and pinned offline
Go/Forge/TLC tools. One implementation writer and one native-engine/cache owner.
Read-only reviewers may work independently. Inspect interfaces, lifecycle hooks,
all tools/inputs/SHA/modes/argv and bounded packet before every first engine GO;
smoke precedes bounded full execution. Java heap at most1GiB and each original
profile at most300s; Go/Forge native90s/isolation100s/supervisor110s. Actual argv and
signal reset are checked. No blind or automatically extended retries.

Every non-trivial change needs independent adversarial source review and
independent behavior verification. Use actual same-copy original/fault/restored
controls, exact expected failures, positive reachable progress and a different
independent fault or action omission. Setup failure, timeout, unexpected panic, skipped
case or missing witness is INCONCLUSIVE. Only Y06's source-pinned, exact locally
captured constructor rejection is an expected API negative; arbitrary panic is
never evidence. Named native12 is existence; only
completed native0/Finished/queue0 is graph exhaustion. Reductions state their
proof and omitted observations. Fairness and resource premises are not hidden
inside a success witness.

Final gates re-fetch PR feedback/current head/main, inspect the whole Y range,
run relevant ordinary suites and the actual current-main merge, check historical
baselines and source restoration, and repair one consolidated final review wave.
Normal-push the existing draft only after review/verification, read back full
PR/worklist bodies and exact head/CI status, then return to feedback-only. Keep
the broader R01/P01 and real-runtime WAITING requirements explicit.
