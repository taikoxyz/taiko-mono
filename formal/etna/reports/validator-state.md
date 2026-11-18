# Concrete validator-state semantics

The model is based on CometBFT **v0.40.0**, commit
`0880b4d378f347ab16e54ec677ff50d803f37d62`. It adds concrete semantics to the
Etna proof package pinned at `8834197bcc6b68606692c60a41a522c33601b601`.
It changes no H1–H4 statement or premise record.

## Reference mapping

| Model operation           | Pinned upstream operation                                                                                                                                                                             |
| ------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `update`                  | `types/validator_set.go`: `updateWithChangeSet`, `verifyUpdates`, `computeNewPriorities`; preserve retained priorities, penalize new validators using total power before removals, normalize and sort |
| `normalize`               | `RescalePriorities`, `computeAvgProposerPriority`, `shiftByAvgProposerPriority`; int64 wrap, truncating division for rescaling, floor division for the big.Int average, saturated subtraction         |
| `increment` / `roundStep` | `IncrementProposerPriority`, `incrementProposerPriority`, `Validator.CompareProposerPriority`; power addition, address tie-break, total-power subtraction and the stored proposer                     |
| `genesis`                 | `state/state.go` `MakeGenesisState`: NewValidatorSet includes one increment; NextValidators increments once more; logical origin may exceed zero                                                      |
| `commit`                  | `state/execution.go` `updateState`: update a copy of NextValidators, increment it once, shift old NextValidators to Validators and old Validators to LastValidators                                   |
| `scheduled`               | Etna COMM-4.3-13: FinalizeBlock at S(t) returns the new selection; updates apply at H(t)=S(t)+2                                                                                                       |
| `openOrigin`              | PROOF-6.2-40/41a: use generation genesis at o; authenticate the supplied preimage at a later p                                                                                                        |
| `Protocol.trustCut`       | SYNC-9-5: compare EL/Comet/FI at every trust target; exempt only validator-state hash at the current generation origin                                                                                |

References: [validator sets](https://github.com/cometbft/cometbft/blob/0880b4d378f347ab16e54ec677ff50d803f37d62/types/validator_set.go),
[genesis](https://github.com/cometbft/cometbft/blob/0880b4d378f347ab16e54ec677ff50d803f37d62/state/state.go),
[commit transition](https://github.com/cometbft/cometbft/blob/0880b4d378f347ab16e54ec677ff50d803f37d62/state/execution.go).

## What is proved

- `commit_pipeline` and `hplus2`: H's update leaves H+1's signing set unchanged and
  the computed updated set becomes current for H+2, independent of H+1's update.
- `replay_append`, `replay_height`, `checked_run_append`, `checked_run_height`:
  arbitrary finite executions compose by per-height replay and advance exactly one
  height per commit. There is no fixed trace-length bound.
- `checked_run_prefix`, `checked_run_records`, `batch_records`: every checked block
  has its own computed commit state; its hash matches that block's cut and its
  state is reached by the actual checked prefix. Checking only the last hash is
  insufficient.
- `origin_uses_genesis` and `later_origin_authenticates`: old retained state cannot
  initialize a recovery generation; an ordinary later proof origin requires its
  own exact-height authenticated preimage.
- `batch_refines`, `certificate_refines`: the concrete batch/certificate is a
  refinement of the existing decoded batch/closed-prefix certificate.
- `trust_cut_at_origin` and `trust_cut_after_origin`: exact scope of the actual
  decoded node-trust comparison exception.
- `checked_block_signers`, `checked_run_signers`, `checked_run_terminal`: each checked
  block's signing set is the registry committee active at its height, and a nonempty
  replay ends in the state whose hash and height the terminal header carries.
- `accepted_replay`: under `ReplaySound`, the guest obligation in `VerifierSound`'s
  shape, every accepted landing in a protocol trace has a replayed certificate whose
  final state's hash and height are those of the checkpoint the landing writes.
  `NonVacuity.replay_satisfiable` realizes `ReplaySound` together with H1–H3's
  `Premises` at the accepting witness.

`validState` refuses empty/unordered sets, invalid numeric values, duplicate keys
or addresses, and missing/nonmember stored proposers before preimage admission.
ABCI power zero means deletion; negative powers are outside the Nat-valued
decoded type, so raw signed-power validation remains a decoder obligation. Removing an absent member, duplicate changes, removing
all members or exceeding the voting-power cap fails. Inputs that would cause a Go
arithmetic panic are refused rather than represented as an accepted commit.

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

The executable H+2 regression starts a recovery generation at height 8, emits the
new selection at S(1)=9, keeps the old signing set at heights 9 and 10 and switches
at H(1)=11. A separate recovery at height 9 keeps its recovery initial set at 11,
discarding the previous generation's pending switch. It also rejects a wrong intermediate hash even when the terminal hash
is correct, and rejects a skipped height.

Run from `formal/etna`, with pinned Lean on PATH:

```sh
lake build
python3 -m unittest tests.test_current_validator_state
ETNA_FULL_TESTS=1 python3 -m unittest tests.test_current_validator_state
```

The slow test compiles each mutated model before checking that unchanged fixtures
reject it: H+1 activation, missing extra genesis increment, post-removal penalty,
wrong signed divisions, wrong switch height, absent per-block hash check, stale
recovery genesis, overbroad origin exception, missing later preimage authentication
and a missing stored proposer. Two further node-trust mutants remove the origin-only
comparison or reintroduce the old origin hash through archive authentication; the full
`nodeTrust` fixture with a different fresh origin hash rejects both.

## Boundary

The existing H1–H4 `VerifierSound`, `ImageCertifies` and `BatchCertificate` still use
the original decoded validity relation. They are not silently strengthened by the
new `ValidatorState.Certificate`; guest/client adoption is a further integration
obligation. `ReplaySound` is not an H1–H4 premise: the joint H1–H4 witnesses would
also need H4's `ProofComplete` for replayed batches, so H4's recovery path would have to
build batches whose replay agrees with `Consensus.activeAt`, which is not yet proved. This patch supplies executable semantics and proofs to discharge that
obligation, not a proof that production guests already do so.

The snapshot keeps ordered key identities, powers, signed priorities and stored
proposer addresses. Their canonical compressed-key decoding, derived addresses,
index-based ENC-A-29a ABI encoding and Keccak collision resistance remain external.
Go implementation refinement, durable checkpoint records, importer/stock-store
refinement, normal-operation liveness and launch resource acceptance remain outside
these theorems. The concrete genesis state is separate from the old origin record
used for EL/Comet/FI and L1 cut authentication.
