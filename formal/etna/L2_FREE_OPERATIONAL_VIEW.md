# Free operational view of L2 committee recovery

`EtnaL2CommitteeFreeView` instantiates `EtnaL2CommitteeRecovery` at the same
two kernel constants and five variables. `Init` names the instance's initial
predicate. `Next` conjoins the original next relation with `KeepInputs`,
which is true in full mode. Partitioned mode restricts the two event kinds
described below. All configurations use `Init /\ [][Next]_vars`, `Profile = "Free"`, four
stake atoms and native stake symmetry. The argument below concerns the six
state invariants at switch height 10, head bound 14, four unit-power bonds
of Q each and generation at most one. It depends on kernel SHA-256
`6de842a3ac059b2644c8c66a9ad8f6eda9841d95e29e3d3f7d1bbb0d289357ee`.

## Equality before symmetry

| Component | Values used in a Free fingerprint |
| --- | --- |
| Current chain | Height, generation, origin, origin fallback and all three assignments. The ledger retains every field, with each exit date mapped to zero or one according to whether the concrete date is zero or positive. The current certificate retains generation, height, round, block ID, members and its exact stake votes. |
| Checkpoint | Presence, saved height and the same projection of the saved ledger. |
| Environment | The entire record, including availability, fallback, threshold, loss flag, change and landing budgets and captured authorization. |
| Verdicts | Actual `TypeOK`, `PipelineSafe`, `SnapshotOrderSafe`, `QuorumSafe`, `RecoverySafe` and `LedgerSafe`, evaluated on the original concrete state and receipt. |

The Free cursor is always zero. The input, result and prior records in a
receipt serve the original checks. Every non-stuttering step writes a fresh
receipt of its own predecessor. The view leaves out the current chain's
`parentCert`, `missBitmap`, `updates`, `snapshot` and `storedGeneration`.
Outside Free the view is the complete five-variable tuple.

## Lifting a Free step

Call a prefix good when every state on it satisfies all six predicates.
Consider two states reached by good prefixes with equal operational fields
as listed above. Model constructors fix the domains of records and functions
on these paths. We compare each offered input in the two states, including
its precise block outcome, call and omission. For enabled steps the
operational fields of the successors agree. The following argument also
accounts for every predicate comparison that reads hidden data.

**Block admission.** The height bound and checkpoint window depend on the
two retained heights. The allowed omission set, live set, proposed votes
and strict current-height quorum depend on `next.members`, `env.available`
and the offered omission. Thus both states reject the same offers at the
outer guards. `ParentAdmits` holds in each good predecessor. At an origin
`QuorumSafe` requires the empty certificate. Elsewhere it requires a strict
quorum, the current assignment's members and matching generation and height,
and `TypeOK` supplies the block ID from those two numbers. Dropping fallback
votes from the fingerprint therefore preserves this guard even when two
concrete admissible certificates used different fallback participants.

**Block start and calls.** `Missing` and the receipt check `WasMiss` both
ask about the key of an occupied bond. Each such key is in `StakeKeys`, so
membership in the parent's exact votes is determined by the retained
intersection. `Count`, `BlockStart`, `Deductions` and the derived miss bitmap
therefore agree seat by seat. An Effects step constructs `Snapshot(h, start)`
before ordinary calls, records the current generation and elects from that
fresh snapshot, whose membership and total use only `start.occupied`.
Revert uses the old ledger and copies its own old snapshot
and stored generation. `ChainOK` in the predecessor gives old snapshot height
at most the old head, strictly below `h = old head + 1`. Both reverted calls
to `Decision` consequently pick the current fallback.

Exit tests only for zero exit height. Forfeit tests checkpoint presence,
positive balance and the forfeited set. The same calls are eligible on both
starts. Exit writes `h`. Forfeit writes `h` on zero and preserves an existing
positive date. Untouched dates are copied. Thus the new zero/positive flags
agree, as do balances, forfeitures, occupancy, counters and sink. Every
copied positive date already satisfies `LedgerOK` and every newly written
date belongs to `11..14`. `LedgerSafe` compares the concrete date for each
bond with the expected `h` or that **same execution's** concrete prior date.
Its remaining equalities use the common deductions, calls and ledger
components. An ineligible call disables the commit branch in both states.

**Committed block.** Both chains shift `next` to `current` and `pending` to
`next`, and build the same new decision and update set from the same input
and election. `PipelineSafe` independently tests the same threshold,
freshness and resulting membership, including every update. For Effects,
`SnapshotOrderSafe` checks the common post-deduction membership, count,
height and generation. On Revert it checks exact copies against that
execution's own prior values. Snapshot and stored-generation typing follows
from their construction or from the prior bounds and unchanged generation.
The new certificate records the exact admitted votes. `QuorumSafe` checks
them against the input and prior live set. `parentCert` saves its own prior
certificate, which was empty at an origin or strict and correctly identified
at the previous head. The new miss bitmap is compared with each prior seat
and parent vote. The complete environment and checkpoint frame equalities
hold pointwise within each execution, including all hidden checkpoint data.

**Refused block.** With `ParentAdmits` true, refusal requires failed
current-height quorum. A nonempty omission with failed quorum would have
failed the outer guard, so any actual refusal uses the empty omission and
the strict quorum test fails on the prior *live* set, as `QuorumSafe`
requires. Chain, checkpoint and environment each equal their own prior
records. Unconditional typing, assignments, ledger and certificate checks
carry over. Commit-only checks are inactive.

**Land.** The guard uses current and checkpoint heights, origin, landing
budget and current certificate height and generation. Its conditions agree.
It saves its own entire chain and increments the common budget. The new
checkpoint projections agree. `RecoverySafe` tests the complete saved
record against its own prior chain, the strict increase and the strict
saved certificate. That certificate is strict because landing requires a
head above the origin and the predecessor satisfies `QuorumSafe`. Saved
`ChainOK` and `LedgerOK` follow directly from the copied chain.

**Authorize, SetM, Lose and Rotate.** Grant uses presence of checkpoint and
absence of authorization, storing the current generation, checkpoint height
and input disable bit. The threshold operation uses the change counter and
old threshold. Loss uses its one-use flag and removes exactly the offered
stake subset of size at most two. Rotation compares the current fallback
and adds the complete rotated set to availability. Each guard and change is
determined by the common environment, retained fields and input. Typing of
changed environment fields is the same on both sides. Chains and checkpoints
remain exact copies of their own predecessors, including for the authorization
and frame comparisons in `RecoverySafe`.

**Recover.** Both representatives agree on authorization and checkpoint
presence, new generation cap, captured generation and height, disable flag,
threshold and change budget. The extra threshold-budget guard applies only
on a matching authorization. A mismatch reaches `RefusedRecovery` even at
the budget limit and compares each unchanged full record to its own prior.
On acceptance the action starts from its complete checkpoint. It carries
over the saved height, ledger, snapshot and stored generation and overwrites
every other chain field. The two operational successors agree on the restored
ledger projection, the new origin, empty current/parent certificates, origin
assignments and reset environment. Each saved ledger is already `LedgerOK`.
The saved snapshot is well formed at a height at most its saved head.
Its stored generation is bounded by its saved generation, itself at most
one by checkpoint `ChainOK`. Accepted recovery has new generation exactly
one. These bounds establish the hidden parts of new-chain typing even when
the representatives restore different snapshots or stored values.
`RecoverySafe` compares each restored ledger, snapshot and stored generation
with its own unchanged checkpoint and checks all origin and environment
assignments against its own receipt. `PipelineSafe` and `QuorumSafe` check
the new origin records. The next block uses the same Effects/Revert cases
above at saved height plus one.

**Stutter.** All five variables, including the last receipt and every
previously evaluated verdict, remain fixed. This also covers the stuttering
option in the specification. In the other cases `AdvanceInput` sets the
Free cursor to zero. The receipt result selects the same predicate branches
in both successors. These cases exhaust the kernel's `Step` dispatch and
the old `Next`.

## First failure, renaming and candidate reachability

`Init` fixes the sole labeled starting state. It has the empty certificates
and initial assignments at heights 11 and 12, a fully seated four-bond
ledger, the switching checkpoint record and its own initial receipt. The
six predicates hold there. The step argument permits replacing a good
representative with any equivalent reachable good one, in either direction.
Matched successors have the same operational fields and the same six actual
verdicts. Following a concrete path up to its first failure therefore reaches
a successor with the same false bit. A previously visited good key has six
true bits and cannot hide that failure. Every explored representative
comes from concrete steps. This argument ends at a first violation on the
canonical record shapes constructed by this kernel. A change to any guard,
constructor or predicate requires checking these cases again.

The four stake atoms name a bond, seat and corresponding stake key in their
respective fields. Permuting them fixes F/G keys, scalar fields, record
labels and booleans. `Init` is fixed. All Free offers are closed under
renaming, and set differences, membership, cardinality, ledger lookup,
copied records and the guards and predicates above commute with renaming.
Taking the stake-vote intersection and the pointwise exit flag commutes as
well. To match a step between representatives related by a permutation,
align their labels, match the input, and rename it back. Pinned TLC applies
native symmetry to the full concrete state before computing the view.
Equality of resulting keys implies projected equality up to a permutation.
Hidden data can cause TLC to retain additional representatives within that
equivalence class. Good-prefix lifting applies to every representative it
chooses. The group size gives no runtime estimate.

`NoCandidate` tests generation zero, head 13 and the candidate assignment
decided at 11 with exactly `StakeKeys` as members. Those fields are retained.
At this endpoint the head exceeds the generation-zero origin (10), so
`QuorumSafe` binds `cert.members` to those same current members and
`TypeOK` requires votes to be a subset of them. Thus when the membership
conditions hold on a good prefix, intersecting votes with `StakeKeys`
preserves the exact vote set required by `NoCandidate`. When they fail
the endpoint is absent regardless of votes. The predicate is invariant under
all four-atom permutations. A named violation reached by normal Free steps
therefore witnesses a concrete candidate block. Stuttering from `Init`
alone cannot reach height 13.

Graph exhaustion, runtime and reachability require separate TLC results.
The historical Free runs retain their individual timeout outcomes. The
argument covers the six finite state properties and this candidate
observation. Fairness, liveness, other witness histories, larger stakes
or heights, and production execution are outside its scope.

## Twelve classes cover every finite Free history

Each class selects one loss cardinality from 0, 1 and 2, and one of the
four ordered generation-zero threshold programs in the table. Code 4
denotes the kernel's distinguished `Disabled` value.

| First SetM | Permitted second SetM programs |
| --- | --- |
| Money(2) | Money(3) or Disabled |
| Disabled | Money(2) or Money(3) |

**From an original history to a class.** `Init` sets the threshold to
Money(3) and the change counter to zero. In generation zero each
`ChangeThreshold` selects a different value and consumes one of two
changes. Before recovery these are the only threshold writes. The first
change can select only Money(2) or Disabled. A second must change that value
again, giving exactly the four ordered programs. A history with one update
fits either corresponding second choice. A history with none fits all four.
Assigning an unused suffix to a class imposes no obligation to execute it.

`ChangeAvailability` requires `~env.lossUsed`, marks it true and removes
the offered subset of at most two stake keys. No action, including recovery,
clears the flag. A history with a loss therefore determines a single
cardinality. A genuine `Lose({})` consumes the flag and belongs to class
zero even though availability does not change. A history without any loss
fits every cardinality. The combination of these choices selects at least
one of the twelve classes for any finite history, including paths that
stop or stutter after a partial program. Recovery leaves generation zero
permanently. It can set the threshold while resetting the change counter,
and all generation-one SetM inputs remain available under the kernel's own
bounds. A first loss can occur in either generation.

**From a class to an original history.** Both specifications have the same
initial state. Every class step satisfies `K!Next`, or stutters as allowed
by the common specification. `KeepInputs` only inspects an already assigned
kernel step. Within that relation only `ChangeAvailability` can flip the
loss flag from false to true, and only `ChangeThreshold` can increase
`env.changes` by one in generation zero. The mutually exclusive branches
then read the actual offer in the new receipt, including empty loss. Every
other step passes directly. In particular stuttering reuses an old receipt
without reapplying an old input filter. Authorization, landing, refusals,
recovery and generation-one threshold changes retain their kernel guards.
Thus every original history keeps its original steps in a matching class,
and every class history is a history of the original kernel.

**Lifting inside one class.** For a fixed class, the same-input proof above
applies before filtering. Two matching good representatives have the same
predecessor generation and full environment. The matched kernel successors
have the same environment, so both classify the same fresh event and use
the same offered input. Both pass the filter or both fail it. A relabeling
of stake atoms preserves the cardinality of the offered loss, and the
threshold constants are fixed. Thus lifting also applies with native
symmetry. `InputClassSafe` independently observes the completed receipt's
result, input, prior generation and prior change counter. A new action in
the matched executions has the same observed membership. A stutter
preserves the previous verdict. `PartitionView` retains this Boolean
alongside the six original checks, so a first class violation has a
fingerprint distinct from every all-good representative.

`NoPartitionWitness` observes a generation-zero head at 11 with two
threshold changes, the program's second threshold, the loss flag set and
the requested number of unavailable stake keys. The view retains the
head, generation and full environment. Rotation adds only G keys, and no
other action removes stake keys. Even at loss count zero the flag requires
an actual loss event. Each named violation therefore witnesses a concrete
nonempty class with the complete threshold program. The full-mode candidate
configuration separately checks progress at head 13.

The twelve class safety searches each have a 45-second limit, 512 MiB, one
worker and seed 1. Their total time allowance is 540 seconds. Summed state
counts can include shared prefixes, and each witness run has its own cost.
Closing the original finite objective requires all twelve distinct safety
searches to exhaust with all seven checks passing and the coverage argument
above to hold. The archived single-graph v1 run timed out at 45.060 seconds.
Its wrapper and config bytes identify that historical result.
