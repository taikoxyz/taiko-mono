# M04: bounded committee selection and H+2 activation

[`EtnaCommittee.tla`](EtnaCommittee.tla) checks deterministic selection from three
immutable snapshots and the actual set/header/snapshot schedule across ordinary
switches and one governance recovery. It extends the same formal project using
the unchanged runner; it is not the product or refinement of the earlier models.

Source is [Etna SPEC at
`d18357214fab30ea512ae9858a11699806d72ba1`](https://github.com/taikoxyz/taiko-mono/blob/d18357214fab30ea512ae9858a11699806d72ba1/packages/protocol/docs/etna/SPEC.md),
COMM-4.3-1..17, STAKE-4.2, PROOF-6.2-12..19/30..32, RECOV-8-48/49/51..55
and RECOV-8.4. No protocol or production implementation is changed.

## Explicit fixture and oracle

Keys A<B<C are modeled as integers 1<2<3; their slots are deliberately A2,B0,C1.
All three snapshots are immutable authenticated interface fixtures, not a model
of registration, activation transactions, slot reuse or Merkle proof checking.

| Key | Effective stake at snapshots 0/1/2 | Active from | Exit effective               | Pending funds        |
| --- | ---------------------------------- | ----------- | ---------------------------- | -------------------- |
| A   | 2/2/2                              | 0           | 1                            | 0                    |
| B   | 2/2/4                              | 0           | beyond the modeled snapshots | 0                    |
| C   | 3/3/3                              | 1           | beyond the modeled snapshots | 5 at snapshot 2 only |

At snapshot 0, C is not active and the A/B tie chooses A first by immutable key,
not B by slot. At snapshot 1, A is excluded exactly at its exit and C is eligible
exactly at activation. At snapshot 2, B's effective power rises; C's pending 5
never contributes to selection or voting power. The fixture does not model how
B's effective increment was activated; that lifecycle belongs to M05.

The two normal profiles use `n_max=2,vp_unit=1` and `n_max=1,vp_unit=2`, with
normalized minimum stake 2. These are toy units, not production token amounts or
deployment parameters. The literal independent expected tables are:

| Snapshot | Two-member output   | One-member output |
| -------- | ------------------- | ----------------- |
| 0        | A,B with stakes 2,2 | A with stake 2    |
| 1        | B,C with stakes 2,3 | C with stake 3    |
| 2        | B,C with stakes 4,3 | B with stake 4    |

Powers are floor(stake/vp_unit), **after** ranking by effective stake. Output is
key-sorted independently of rank: at snapshot 1 the ranking is C before B, but
the two-member encoding is B,C. Expected tables do not call `Selected`, its
ranking helper or the pending-funds/tie mutation switches.

The actual model projects committee identity to **selection snapshot, members
and powers**. It does not verify targetEpoch, record-hash/ABI encoding, complete
validator-state hashes or proposer priorities. `Header` is a symbolic commitment
to membership/powers, excluding selection-snapshot metadata; it is not the
actual CometBFT hash algorithm or its set-order encoding. Snapshot provenance is
checked separately.

## Actual schedule and independent history

L=3, Etna start=0, head 0..7 and generations 0/1 are fixed bounds. Ordinary
switches are heights 2 and 5, with D at 1 and 4 and H at 4 and 7. L1 snapshot/tip
values are 0..2; committed anchors are nondecreasing within a generation and no
earlier than its origin.

`Initialize` derives the initial committee from snapshot 0. `Commit` then stores
actual signing committee, current/next header commitments and reported terminal
snapshot in separate state fields. At switch S, selection uses
`max(anchor(D),generationOriginL1)`, while the proof root belongs to **S's own
anchor**, which may be newer than the selection snapshot.

```text
S:      old set signs; derive new pending set; header-next is old
S+1:    old set signs; header-next is new
S+2:    new set signs
```

The operational cached `active` and `pending` implement this schedule without
claiming a one-to-one mapping to every CometBFT state field. The oracle reconstructs
expected sets from raw historical inputs and a fixed `switchHeight+2`, never the
configurable activation delay used by the action.

Two additional invariants prevent the oracle from following a bad implementation:

- `SwitchCalendarCorrect` independently requires exactly one derivation at every
  committed `(generation,height)` with literal `height % 3 = 2`, and none at other
  committed heights. It does not call the operational switch helper.
- `RawInputsMatchHistory` links captured D anchor, switch anchor and origin to
  immutable generation-keyed committed-anchor/parent and origin records. A
  self-consistent claimed root or claimed D input is insufficient. The first
  recovered switch resolves D's parent to its retained **old-generation** block,
  not an uninitialized new-generation record at that height.

History/expected tables are assertion inputs, not action enabling conditions.
Old-generation committed records remain for observation; recovery does not give
the discarded suffix authority on the new chain.

## Recovery and the L1 snapshot boundary

`Land` advances a retained checkpoint and records the snapshot of the committee
that actually governed its terminal block. L1 `l1ActiveSnapshot` represents slot
284; per-L2-block `reportedSnapshot` is the prover's terminal-block metadata.
They are different layers and do not automatically advance together.

Recovery is an assumed authorized interface event from R=2, at retained c=1,2 or
3, with at most one recovery. It resets the head to c, directly installs the
R-selected committee for c+1 and clears old pending updates. It preserves slot
284 and the last landing until a real new landing advances them. This model
does not reverify DAO authorization, readiness or proof availability.

| Recovery checkpoint | New generation behavior                                                                                     |
| ------------------- | ----------------------------------------------------------------------------------------------------------- |
| c=1=S-1             | First recovered block 2 is itself a switch; its D belongs to the old prefix and selection is floored at R=2 |
| c=2=S               | Old pending update from switch 2 is discarded; recovery committee continues through old activation height 4 |
| c=3=S+1             | Recovery committee governs height 4 immediately; old pending cannot activate                                |

The positive before-switch witness requires an actual old D anchor **below** R,
not merely a recovery where the floor happens to be unnecessary. The next
ordinary switch actually committed in the new generation schedules a fresh H+2
update. An epoch number does not resurrect an old-generation pending update.

`L1SnapshotMatchesLanding` binds slot 284 to the last actual landing;
`NoL1SnapshotRegression` independently observes its maximum. Installing a new
committee by recovery alone cannot start M05's exit-confirmation clock from a
new snapshot. Proof verification and complete registry withdrawal logic are not
part of this module.

## Checks, controls and coverage

Both normal profiles exhaust the complete selected action graph: initialization,
L1 advance, all allowed anchors, L2 commits, landings and one recovery at the
three stated boundary positions. Finite domains appear in constants/action
ranges, not hidden state constraints. No fairness or liveness is asserted.

Controls independently exercise early/late activation, stale pending after
recovery, selection from the new switch anchor, missing origin floor, wrong proof
root, pending-fund power, slot tie breaking, wrong actual header/snapshot writes
and premature L1 snapshot advancement. Additional controls narrowly omit only
generation0/height2/candidate-anchor2's switch or forge both its captured switch
anchor and root. They must hit the new independent calendar/history invariants.

Positive witnesses show unchanged members with changed power, complete
replacement with old sets still signing S and S+1, recovery at each of c=1/2/3,
and the first recovered block scheduling its own switch with old D below R.
Each configuration declares its exact expected outcome. A parser/runtime error,
timeout or wrong invariant does not count as a successful negative control.

Independent review found model assertion gaps, not a protocol defect. The narrow
omitted-switch mutation retained all 18 predecessor configuration outcomes until
an independent literal calendar check caught it. A forged-root/captured-input
challenge also passed a normal predecessor baseline and its original wrong-root
control; a complete second predecessor matrix was not claimed for that challenge.
The new assertions bind those sources directly and retain permanent controls.

## Remaining boundaries

This checks the stated finite fixture/calendar. It does not verify arbitrary
stake distributions, empty candidate/invalid numeric rejection, uint48/u64/MAX
edges, fixed-supply deployment bounds, registration/withdrawal effects, dynamic
registry history, actual MPT/SEC1/PoP/ABI/hash algorithms, targetEpoch/record hashes,
Comet proposer-priority arithmetic, BFT quorum/fork choice, finality, crashes,
large nonzero Etna starts, repeated recoveries, actual guest/client refinement or
an unbounded composition theorem. Authenticated snapshots, block/proof validity
and authorized recovery are explicit environment contracts.
