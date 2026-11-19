# Concrete validator-state semantics

The model is based on CometBFT **v0.40.0**, commit
`0880b4d378f347ab16e54ec677ff50d803f37d62`. Its Etna authority is main
`2e6763e21bc236cfcda6011d164b32040f9e0c8d` (after #22412), as for the rest of this package.

Since #22412 the validator state is outside settlement (SYNC-9-5c). The app commits it in
`app_hash` (CONS-3.1-8, ENC-A-29b), and no landing record, cut, `LandInput`, statement or
H1–H4 premise carries its hash. Guests do not check `app_hash` (PROOF-6.2-42), and nodes no
longer compare a landed validator-state hash (SYNC-9-5).
`EtnaModel/CurrentValidatorState.lean` is the arithmetic of that state: the per-height update
CometBFT applies and the app must reproduce exactly. No H1–H4 statement or premise uses it.

## Reference mapping

| Model operation           | Pinned upstream operation                                                                                                                                                                             |
| ------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `update`                  | `types/validator_set.go`: `updateWithChangeSet`, `verifyUpdates`, `computeNewPriorities`; preserve retained priorities, penalize new validators using total power before removals, normalize and sort |
| `normalize`               | `RescalePriorities`, `computeAvgProposerPriority`, `shiftByAvgProposerPriority`; int64 wrap, truncating division for rescaling, floor division for the big.Int average, saturated subtraction         |
| `increment` / `roundStep` | `IncrementProposerPriority`, `incrementProposerPriority`, `Validator.CompareProposerPriority`; power addition, address tie-break, total-power subtraction and the stored proposer                     |
| `genesis`                 | `state/state.go` `MakeGenesisState`: NewValidatorSet includes one increment; NextValidators increments once more; logical origin may exceed zero                                                      |
| `commit`                  | `state/execution.go` `updateState`: update a copy of NextValidators, increment it once, shift old NextValidators to Validators and old Validators to LastValidators                                   |
| `scheduled`               | Etna COMM-4.3-13: FinalizeBlock at S(t) returns the new selection; updates apply at H(t)=S(t)+2                                                                                                       |

References: [validator sets](https://github.com/cometbft/cometbft/blob/0880b4d378f347ab16e54ec677ff50d803f37d62/types/validator_set.go),
[genesis](https://github.com/cometbft/cometbft/blob/0880b4d378f347ab16e54ec677ff50d803f37d62/state/state.go),
[commit transition](https://github.com/cometbft/cometbft/blob/0880b4d378f347ab16e54ec677ff50d803f37d62/state/execution.go).

## What is proved

- `commit_pipeline` and `hplus2`: H's update leaves H+1's signing set unchanged and
  the computed updated set becomes current for H+2, independent of H+1's update.
- `replay_append` and `replay_height`: arbitrary finite executions compose by per-height
  replay and advance exactly one height per commit. There is no fixed trace-length bound.

The rule edges are SYNC-9-5c (`commit_pipeline`, `replay_append`, `replay_height`) and
COMM-4.3-13 (`hplus2`), both narrow: they cover the arithmetic,
not the app's durable record, its commitment in `app_hash` or the stored-set lookup.

The replay-soundness layer is deleted: the per-block hash check (`checkBlock`, `checkRun`),
the concrete `Batch` and `Certificate`, `ReplaySound` and `accepted_replay`, the origin
admission (`openOrigin` and its two lemmas) and the node-trust exception (`trust_cut_*`).
Each rested on a validator-state hash in the landing statement or the slot 285 record, which
#22412 removed (PROOF-6.2-41a and SYNC-9-5b are retired).

`validState`, the well-formedness check of an ENC-A-29a payload, refuses empty/unordered sets,
invalid numeric values, duplicate keys or addresses, and missing/nonmember stored proposers.
ABCI power zero means deletion; negative powers are outside the Nat-valued decoded type, so
raw signed-power validation remains a decoder obligation. Removing an absent member, duplicate
changes, removing all members or exceeding the voting-power cap fails. Inputs that would cause
a Go arithmetic panic are refused rather than represented as an accepted commit.

## Evidence

`tests/CurrentValidatorState.lean` kernel-checks literal numerical outputs. The
reference program `tests/reference/comet_validator_state.go` was run against the
pinned, unmodified Go module; its recorded output is beside it. To reproduce after
installing the module, run the reference program from the v0.40.0 Go module directory.
This optional reference run is separate from the dependency-free Lean gates.

For powers 3 and 1 (addresses 2 and 1), genesis produces priorities [-1,1] with
proposer 2; NextValidators has [2,-2] with proposer 1. Removing power 3 and adding
power 2 produces [0,0], proposer 1, after the commit's update and increment.

A stock-Go counterexample demonstrates why historical lookup is not a substitute:
starting in set order with (address,power,priority) [(3,3,5),(2,2,6),(1,1,-6)],
two separate single increments produce [0,2,-2], while one increment(2) produces
[4,3,-5]. Both store proposer 3. In the first result, the stored proposer is not
simply the member with the greatest post-increment priority.

The H+2 regression starts a recovery generation at height 8 with epoch length 10.
FinalizeBlock at S(1)=9 returns the epoch-1 selection and at heights 8 and 10 returns
nothing; committing it keeps the old signing set at height 10 and makes the new set sign
H(1)=11.

`testdata/etna_current_conformance/validator_state.json` holds ten genesis/commit replay
vectors from this model, tagged COMM-4.3-13, CONS-3.1-8 and SYNC-9-5c.

Run from `formal/etna`, with pinned Lean on PATH:

```sh
lake build
python3 -m unittest tests.test_current_validator_state
ETNA_FULL_TESTS=1 python3 -m unittest tests.test_current_validator_state
```

The slow test compiles each mutated model before checking that unchanged fixtures
reject it: H+1 activation, missing extra genesis increment, post-removal penalty,
wrong signed divisions and wrong switch height.

## Boundary

The app's durable SYNC-9-5c record, the appHash encoding (ENC-A-29b), the checkpoint
import's derivation of the state after s (DATA-5.4-3; the import model reads its checks as
authenticated adapter flags) and stock CometBFT store and Go implementation refinement are
not modelled. The snapshot keeps ordered key identities, powers, signed priorities and stored
proposer addresses. Their canonical compressed-key decoding, derived addresses, index-based
ENC-A-29a ABI encoding and Keccak collision resistance remain external, as do
normal-operation liveness and launch resource acceptance.
