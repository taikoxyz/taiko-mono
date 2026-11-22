# Draft L2 staking boundary model

This separate namespace follows unmerged design PR22425 at
`69e26df443e9b5a0f05127d4179e4833fc95823c`. `source.json` records the exact
SHA256 of its five core documents. Existing current-rule models, accepted source
bundles, runtime classifiers and proof claims retain their previous meanings.
This namespace grants no runtime or proof credit to this draft.

The standard-library model checks selected symbolic state transitions:

- `initial_state` initializes an origin and the next two signer sets from its
  authenticated origin fallback. For recovery, supply the complete checkpoint's
  permanent issued bond identities, including exited or unseated bonds, its
  snapshot, stored generation and miss counters. Omitted checkpoint data means
  fresh state; it is not a rule resetting recovery state. Old pending signer
  updates cannot enter this constructor.
- `advance` counts the parent signers' misses using the parent's live seats,
  applies rounded-up penalties and takes a snapshot before ordinary actions.
  Transactions at X reach the snapshot at X+1 and signers at X+3; penalties
  applied at H reach signers at H+2. Failed block-start calls preserve all state
  owned by that call while ordinary actions continue. The output tracks the
  sets for H, H+1 and H+2 and emits complete key/power differences.
- `derive_set` independently checks the full snapshot height, symbolic key
  validity, record shape, exact power sum and stake threshold. The maximum
  uint256 threshold always selects fallback. Snapshot total stake and the sum
  of integer powers are independent inputs: rounding loses stake remainders.
- `required_commits(p,h,sets)` includes h and interior heights whose successor
  changes keys or powers. Source labels and member ordering add no commit.

All records are immutable. Public entry points explicitly raise `ValueError`
for malformed configuration, live state, anchor premises or actions; numeric
validation survives Python optimization. Invalid candidate records instead
select fallback as the draft requires. Refusal means outside the modeled trace
bank, not a rule rejecting a real block. Ordinary actions are already
authorized, successful projections. A refused action does not model transaction
revert processing, receipt semantics or subsequent transaction execution.

Miss counters may remain nonzero on empty seats: exit releases a seat, and
block-start processing ignores empty seats. Taking a seat resets its counter,
so a new occupant inherits no misses. Preserve these retained counters when
supplying trusted checkpoint state.

`Action("register", bond_id, key, amount)` records the expected sequential id
returned by registration. The id is a model trace expectation, not an argument
of the production register ABI or a caller-selected issuance identity. The bond
list retains complete identities so exit and seat reuse cannot release keys or
reuse ids. Withdrawal execution and custody are outside this projection; an
exited zero-balance identity remains represented by its permanent bond record.

Keys are nonempty symbolic strings standing for keys already checked under the
compressed-key and proof-of-possession rules. `Member.valid_key=False` and
`reserved_bits` supply failed validation results; these are not key decoding or
storage authentication. Anchor fallback lists are already authenticated, with
symbolic lexical order standing for their canonical order. The model implements
no curve math, hashing, signatures, storage/MPT witnesses, token transfer, owner
authorization, DAO message delivery, actual Comet priorities, native engine,
execution client or proof guest. It has no network or filesystem side effects.

Arbitrary `missing_keys` inputs can describe a parent commit that could never
reach quorum. Some small-unit probes intentionally isolate transition arithmetic
in that way. These helpers do not verify commit quorum, signatures or consensus
reachability. A separate numerical trace uses four equal-power members and
omits only one, so the other three satisfy the strict greater-than-two-thirds
power condition. That one symbolic trace does not establish global quorum
validation, cryptographic validity or deployment readiness.

The selected hand-derived bank uses at most five advances, four distinct
symbolic keys per lifecycle trace and four seats; direct selection vectors
additionally reach 128/129 records and integer boundaries. Most lifecycle traces
use small units. One numerical trace uses `Q = 10^27 / 4`, four bonds of Q and
`vp_unit = minStake = Q`, satisfying the fixed-supply admission relation and
production vp_unit lower bound arithmetically. `Config` intentionally validates only
the conditional bank's arithmetic/seat bounds. It does not validate deployment
requirements such as the 10^27 token supply, minStake*n_max supply relation or
production vp_unit minimum. The bank is not a proved quotient of production
token units, exhaustive exploration or full-protocol verification.

Run the focused tests from the repository root with the existing managed Python
environment: `python -m unittest discover -s formal/etna/tests -p
'test_l2_staking_model.py'`. Repeat with `python -O` to check that explicit
validation does not depend on assertions. Execution evidence is recorded by
the review report, separately from this source description.

## Quorum-constrained extension at178

`quorum.py` and `quorum_source.json` separately qualify the20-file design
increment to unmerged178d7a7a. The original source manifest and model above
retain69 and their historical scope.

`FlagVote`, `LastCommit` and `Availability` are frozen symbolic records.
`committed_power` requires one keyed commit/nil/absent flag per parent member;
only commit contributes power. `available_power` uses unique known eligible
keys. Both use the selected members' authoritative weights and require
3*contributing > 2*total. Keys in a raw global online list must be projected to
this particular set before use; unknown/duplicate keys refuse. Origin and
fallback sets carry unit powers; candidate sets may carry differing powers.

`advance_with_quorum` checks a parent certificate against current_signers and
current availability against next_signers, never pending_signers or a union.
At the origin, parent and previous_available must both be None. For a temporal
trace, the caller retains the last successfully admitted availability and
supplies it as previous_available: parent commit/nil may then come only from
that bound, while absent may also describe an omitted available vote. The
stateless API cannot prove that a caller retained the actual previous input;
without that input it offers only independent one-step power compatibility.

Rejected quorums/domains/actions leave the complete predecessor unchanged;
they execute no state advance and cannot skip a stalled height to reach future
fallback signers. A failed modeled block-start call inside an admitted block
still permits ordinary actions. The old call_succeeded bool is not an EVM
no-code success oracle: that exact execution distinction is outside both models.

Generation/height checks are not full chain-domain, round, BlockID or signature
authentication. Keyed flag rows do not validate stock wire ordering. The
availability bound states possible voting power, not which keys actually signed
the committing round. Even continuous power-compatible traces establish no
cryptographic validity, stock locking/message behavior, global reachability,
unconditional liveness or production readiness. Actual results, exact finite
bounds and independent reviews are in [the report](../L2_QUORUM_REVIEW.md).

## Unsigned vote wire extension at178

The `vote_wire.py` encoder and frozen `vote_wire_vectors.json`
cover raw canonical field bytes, preserving empty versus32-zero hashes and
raw int64/int32 timestamp values. `vote_wire_native_expectations.json` keeps
the narrower stock Timestamp domain separate. Its original provenance
filenames are descriptive; `vote_wire_sources.json` selects the actual inputs.
This source/build map also pins the full gogoproto dependency manifest and the
existing stock SDK/module profile solely for unsigned library comparison.

The native Go observation producer receives only the projected raw fields,
never literal expected bytes or result flags. `run_vote_wire.py` owns the
guarded offline smoke/full lane and exact event/receipt comparison. Actual
observations (23 exact stock bytes, two marshal panics and four native
rejection-only observations; six Timestamp rejections total), execution status and portable invocation are recorded
in [the report](../VOTE_WIRE_CONFORMANCE.md). All29 raw full wires match an
independent pre-implementation oracle. The shared cache requires its established
operator-supplied physical lock; smoke custody is local consistency, not signed
origin. No wire-format
success establishes signatures, vote admission, slash execution, a trusted
deployment or actual protocol liveness. Old fixture normalization and all old
proof/runtime claims remain unchanged.
