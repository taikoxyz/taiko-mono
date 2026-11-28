# Independent source contract: L2-COMMITTEE-RECOVERY-TLA

Status: corrected v3 desired finite witnesses, derived by source inspection only.
Supersedes contract-v2.md SHA256 e80490b7b8e0f550a43c4e6bfc90ac066ce3a2d54ddb0df916bd764a29ec0702.
The unchanged v1/v2 files retain both oracle defects as evidence;
see ERRATA-v2.md and ERRATA-v3.md. These witnesses remain unexecuted.
No model, Python oracle, engine, test, or TLC execution occurred in this task.
This note owns only this temporary directory and does not modify the repository.

## Authority

Repository worktree HEAD: 5abc1748ccb0896819dfd054bc36f44f0d3e0d12.
Normative design: unmerged PR22425/head178d7a7a66b14305c2f6467ae77163f93dd677cf,
base3602629758beb653423a23608fd1960810efcfac. The inspected full view is the
actual base plus head overlay; five core hashes match quorum_source.json.
SPEC SHA256: cae2e783a06b81b36dd0d412d678c67f764b6d96143c676aec99df8008eee7e0.
This is a new source-qualified stage, not a restart or completion claim for R01.

## Exact normative clauses and decisive short excerpts

Line numbers refer to the inspected SPEC.md at the pinned draft head.

* STAKE-4.1-13a/13b/14a/14c/14d/14e, lines152-157: permanent issued ids and keys;
  eligibility iff no exit, unwithdrawn and balance >= minStake; lowest empty
  seat; taking it resets misses; live mappings update in the taking/releasing
  call; power is floor(effStake/vp_unit). Bond0 and seat0 are real identities.
* STAKE-4.2-4..7, lines182-185: generation store, misses, penalties, then
  snapshot. Exact excerpts: "the call runs on the parent's post-state";
  "Only this call writes these values"; "a stake change in block X enters the
  snapshot at X + 1". Empty seats are ignored, not reset by counting.
* CONS-3.2-13, line90: "A call to an address that holds no code succeeds and
  changes nothing". A revert/exception also preserves call-owned state, while
  ordinary transactions continue. An infrastructure/storage fault is not an
  EVM failure and cannot admit a block through that branch.
* COMM-4.3-1/3/3a/8/8b/9/13/13a/14/16/19, lines192-216:
  every H decides H+2 from H's snapshot and anchor; M=uint256max disables all
  candidates, even snapshotTotalStake=max; snapshotHeight must equal H in the
  full word; origin keys sign the first two heights, with unit powers;
  FinalizeBlock(H) diffs signers(H+1) against signers(H+2); old pending updates
  are discarded by recovery; every block selects again without hysteresis.
* PROOF-6.2-12a/b/c/16/17/18/29a, lines396-401: p+1 uses the origin list or
  header(p).next; p+2 uses the origin list at p=o or p's snapshot and anchor;
  p's set is authenticated from header(p).current for the p+1 miss rule.
  Terminal h and each interior x with a key-or-power change to x+1 require a
  same-height/round/BlockID strict >2/3 precommit certificate. Source-label
  changes with identical keys/powers add no commit. Each header current/next
  commits the actual set for that height and its successor.
* PROOF-6.2-11/33/47, lines395/402/407: p-only exceptional authentication can
  supply p-anchor minTotalStake/fallbackKeysHash only. It cannot authorize
  other Inbox values or inherited/new-block anchors. Here authenticated roots
  are symbolic role-tagged premises, not MPT/ancestry implementation claims.
* FORF-4.4-2/4/7/9/11/13/14/16/19/21, lines221-227: identity checked against
  landed state before authorization; issued, unwithdrawn, nonzero balance,
  lifetime flag false, timestamp <= validUntil. Exact excerpt:
  "penalty = ceil(balance * forfeitBps / 10000)"; deployment fixes
  "0 < forfeitBps <= 10000"; same transaction sets flag and earlier-only exit,
  releases seat, sends full penalty to sink, and is atomic. Transactions at X
  first affect signers X+3. A forfeited bond cannot take a seat again.
* RECOV-8-21, line540: "in one proposal" set M=uint256max and then recover;
  use fallback while forfeiting offline bonds, then lower M. Without max,
  the unusable offline candidate can return at c+3. No blocks means no misses,
  penalties, withdrawals clock, or future committee activation.
* RECOV-8-42/47/48/51/53/55/56/58/59, lines547-551: recover itself does not
  forfeit or exit; preserve c/landing/FI; rebuild actual c's EL state; discard
  all old pending and every staking operation above c; origin fallback alone
  signs c+1,c+2. No arbitrary checkpoint constructor or carried old weights.
* RECOV-8.1-4/6/7/9, lines556-559: recovery reads the current latest c and a
  landing invalidates an authorization for old c; settle up to the last block
  actually settleable before authorizing. Availability of audit evidence,
  authorization, history, signer admission and fallback readiness remain
  explicit assumptions. Fallback readiness includes >2/3 online AND no
  controller at >=1/3. Two or three fallback keys cannot meet that last bound.
* RECOV-8.4-3/9/10/12/13, lines577-579: origin freezes fallback keys at R;
  first new block has empty LastBlockID/LastCommit and bitmap0, regardless of
  the origin's old-generation committee; anchors are >=R.
* START-10-11/12/13, line648, and PARAM-11-12, line701, admit the chosen
  minStake/vp_unit/n_max/missLimit/missSlashBps/forfeitBps parameters.

## Finite monetary instance and abstraction

Q=10^27/4=250000000000000000000000000 base units. Four bonds A-D each hold Q;
ids/seats are0..3. vp_unit=minStake=Q, n_max=4, missLimit=2,
missSlashBps=forfeitBps=10000. Thus total stake=4Q=10^27, admission bound is
equality, vp_unit exceeds867361738, and powers are exact positive integers.
Every modeled full forfeiture or miss penalty deducts the whole balance:
ceil((q*Q)*10000/10000)=q*Q. A q-unit ledger therefore commutes exactly with
these selected transitions. Thresholds use distinct values2Q,3Q,uint256max;
the main initial threshold is3Q, so the old h5 snapshot with3Q remains usable.
max is a distinguished sentinel, not another q-scaled integer. There is no
claim for arbitrary rates, amounts, configurations,128 seats, or a production
quotient. No partial proportional penalty is invented.

Use four separate fallback keys F0-F3, each a different controller, each
caught up and online. They have no seated bonds. All eight keys are distinct
symbolic prevalidated SEC1 keys. Optional G0-G3 rotation needs four further
distinct healthy controllers, but is not necessary for this minimum circuit.

The proposed abstraction is a concrete small staking ledger (issued/key,
balance, seat, exit, forfeited, misses, sink), NOT freely supplied candidate
snapshots. Successful block-start derives its snapshot from that ledger;
ordinary calls mutate live state afterward. Snapshot authentication, key
validation, EVM/token transfers and authority are assumed successful, not
implemented. Init may rely on a trusted pre-fork staking state with four
registered bonds on a switching chain. The witness uses actual S=10; JSON
height offsets0..9 mean actual heights10..19. The finite model may use actual
heights directly, avoiding a claim about absolute-height translation elsewhere.

Keeping permanent issued/key identity, exit and forfeited flags is necessary.
For this selected future with no withdrawals, top-ups, slashing evidence or
owner changes, owner data may be represented by an authorized-action premise;
unused principal of an exited bond may NOT disappear from total custody.
With full forfeiture, A/B principal becomes zero and sink increases by2Q.
Released-but-unforfeited D retains Q in the old suffix. Store the real landed
c ledger and restore it on recovery; do not reconstruct it from seat members
alone. Economic ownership, ETH fees, transfer callbacks and withdrawal clocks
are outside these selected actions. Track sink if claiming TAIKO conservation.

## Reachability and certificate contract

The model owns all pipeline/history/availability state. Quorum admission uses
parent's own signers/weights and separately the current height's own signers;
each exact contributing set is persisted with its domain. A stalled attempt
can change environmental availability/L1 but cannot execute block-start or
ordinary calls, advance height, overwrite snapshots, or activate pending.

At committed heights, certificates are symbolic authenticated statements with
generation, height, one round and one BlockID and distinct precommitting keys.
Their power must be >2/3 of that height's actual set. Parent flags can be
omissions/nil only within a persisted possible-vote ledger from that height;
the model must not accept an independently re-created caller availability.
This establishes reachability in the certificate-level conditional transition
system. It does not establish stock round/lock/message/signature reachability
or arbitrary Byzantine-schedule liveness.

Main witness audits/lands c=13 before backend proof service becomes unavailable
for the suffix; retained audit/history is available, but no later suffix proof
can be completed before recovery. This is a modeled external proof-production
pause, not a claim that otherwise valid blocks are mathematically unprovable.
Assume valid recovery authorization/audit and finalized L1 evidence at R, all
fallback signer readiness/trust and distinct controllers. After recovery assume
governance delivery and ordinary transaction execution of the two forfeitures.
All anchors satisfy age/finality/current-generation constraints symbolically;
FI is empty, rules remain0, no planned stop, U>=6 (a valid allowed deployment).
Every committed block adopts the latest finalized modeled L1 threshold,
fallback and landing values. This selected graph explores no delayed/inherited
older anchor view or anchor-lag interaction.

The final C/D set has2/2 online power and can legally produce, but each controller
has1/2 power. It is NOT 'healthy' under RECOV-8.1-7's concentration definition.
ACCEPTANCE section4 identifies concentration as monitoring, not an on-chain
rule; the shortfall must be disclosed. A strictly <1/3-concentrated candidate
endpoint requires extra independent active keys and is outside this instance.

## Core properties frozen before authoring; supplemental correction after static review

The v2 core/main histories were frozen before authoring. The v3 true-no-code
withdrawal and scope qualifications follow independent static model review,
before full model execution; they must not be described as wholly pre-authoring.

Selected kernel operations are Exit, block-start success or revert/exception,
miss-count/full penalty, per-block election/update/header pipeline, L1 M change,
atomic M=max+Recover, authorized full Forfeit, and abstract Land. Land requires
an actually produced committed boundary and a trusted proof premise, saves its
complete staking state, and advances c monotonically. PrepareProof and guest
proof-origin/cut construction are outside this stage. The proof clauses and
literal proof-boundary tables are future-reference context only.
There is no Register, TopUp, Withdraw or ordinary double-sign operation here.
Code at the staking proxy is assumed present throughout this selected graph.
True no-code calls have the single-step semantics CONS-3.2-13 specifies, but
successful Exit/Forfeit calls at that same no-code address cannot be assumed.
Code absence, replacement/repair and subsequent code availability are OPEN;
they receive no positive-history or operational-transition credit here.

Safety: ordering/snapshot immutability; H+2/X+3; strict parent/current quorums;
no progress at a stalled height; source/key/power/header provenance; recovered
ledger exactly equals actual latest checkpoint; preserved settled prefix;
origin first-two and dropped old pending; max/stale snapshot select fallback;
issued/seat/exit/forfeit/sink consistency. Empty-seat miss counts are allowed to
remain nonzero after exit; counting ignores them. Do not introduce a zero-miss
invariant on every empty seat. Freshly taking a seat would reset its counter,
but taking a new seat is outside the selected kernel.

Required corrected source-derived witnesses are in oracle-v3.json. Invariant negations for
positive reachability must be observational, never transition-enabling guards.
Expected tables must not call the operational selection/pipeline helpers.
This stage checks safety and existence of selected finite conditional witnesses.
No temporal fairness, leads-to or liveness property is actually checked; no
unconditional recovery or wall-clock progress claim is made.

Meaningful selected fault controls: preserve old pending across recovery; restore current
suffix instead of c; use pending/union quorum; advance misses before failed
quorum; change activation by one; take snapshot after forfeiture; treat max as
ordinary threshold; accept a snapshot retained after revert as fresh; forget whole-set
deletions. Proof-origin substitution and power-only commit controls belong to a
future stage; this instance has no reachable power-only change. Require the
intended named assertion after valid setup and
retain positive witnesses proving the relevant state is reached in the normal
graph. Setup/parse errors and timeouts are not detected semantic mutations.
