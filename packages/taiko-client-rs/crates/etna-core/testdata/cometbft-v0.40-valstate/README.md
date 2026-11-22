# CometBFT v0.40.0 validator-state vectors

Run `./generate.sh` from any directory. It runs `generate.go` with Go 1.27.2 against the
unmodified `github.com/cometbft/cometbft v0.40.0` module and writes `vectors.json`. A second run
must produce a byte-identical file (`shasum vectors.json`). Never edit `vectors.json` by hand.
The adjacent `comet-wire.json` is copied from the same baseline's
[ABCI wire oracle](../../../abci/testdata/README.md).

The generator calls only exported `types.ValidatorSet` methods, in the order stock CometBFT
does:

- genesis (`state.MakeGenesisState`): `Validators = NewValidatorSet(vals)` and
  `NextValidators = NewValidatorSet(vals).CopyIncrementProposerPriority(1)`;
- each height (`state/execution.go` `updateState`): `next' = NextValidators.Copy()`, then
  `next'.UpdateWithChangeSet(updates)` when there are updates, then
  `next'.IncrementProposerPriority(1)`; `Validators' = NextValidators.Copy()`.

Keys are stock `secp256k1eth.GenPrivKeySecp256k1Eth` keys. The secret of seeds 1 to 255 is 32
repetitions of the seed byte and the secret of seed 256 is the 32-byte big-endian encoding of
256, so seeds 1 to 128 and 129 to 256 are two disjoint sets of 128 keys. The top-level `keys`
table lists the 33-byte compressed public keys of seeds 1 to 256 once each, as hex, so key
index i is seed i + 1. The random cases draw from seeds 1 to 255 only.

## Format

Each case is a list of steps. `updates` is a string of comma-separated `key:power` items, and
`current` and `next` are strings of comma-separated `key:power:priority` items in set order,
where `key` is an index into `keys`; these strings keep the file small and are never rewrapped
by the repository's JSON formatter. An empty `updates` string means no updates.

The first step is the genesis: its `updates` are the genesis members. Every later step is one
height, and its `updates` are the validator updates applied there. The cases that predate the
per-block ones restate the committee in full: every old member at power 0, overwritten by the
new committee's members, so unchanged members repeat their power. Stock CometBFT reaches the
same state from that list as from the difference alone, which is what
`committee::validator_updates` returns: a leaver at power 0, a newcomer or changed power at its
new power, no unchanged member. `per_block_diff_ten_heights`,
`replace_128_with_128_other_keys` and `fallback_key_reweighted_as_seat_key` record that
difference alone, as FinalizeBlock returns it, and the Rust tests check that the decider's list
from the set in force to the recorded next set is exactly the recorded list.

A step holds the state after that height: `current` is `State.Validators` and `next` is
`State.NextValidators`, each in CometBFT set order (power descending, then address ascending)
with proposer priorities, and `current_proposer` / `next_proposer` are the indexes of each
set's stored `ValidatorSet.Proposer`. A step whose updates CometBFT rejects carries the stock
Go `error` string instead and ends its case. `negative_power` holds CometBFT's int64 power -1;
a Rust `u64` power carries the same 64 bits. A case without updates may carry
`validators_hash`, the stock `ValidatorSet.Hash()` of its genesis set and so of every set in
the case.

The named cases are genesis sets of 1, 4 and 120 members; a heavy added member that ends
lowest; removal of the stored proposer; power-only changes; same-power updates; a rescale
trigger (powers 1 against 1,000,000); priority ties; a total just below
`MaxTotalVotingPower`; a full committee replacement; one member re-weighted at each of ten
consecutive heights (`per_block_diff_ten_heights`); 128 keys at power 1 replaced by the 128
other keys in one list of 128 removals and 128 additions (`replace_128_with_128_other_keys`);
a key at power 1 among four re-weighted to 250,000 while the other three leave, in one list
(`fallback_key_reweighted_as_seat_key`); 128 members at exactly `MaxTotalVotingPower`, with
`validators_hash` (`maximum_128_members`); the rejected change sets (`duplicate_update`,
`remove_unknown`, `remove_all`, `negative_power`, `power_overflow`, `total_overflow`) and a
zero-power genesis member. `random_0` to `random_7` come from one seeded PCG(22280, 2026): 50
heights each, with a committee switch every 5 to 20 heights.

## Why `/validators` is not a reference

CometBFT's `/validators` RPC calls `LoadValidators`. The store keeps a full validator set only
at the initial height, at the height a change takes effect (h + 2 for updates returned at h)
and at every multiple of 100,000. For any other height, `LoadValidators` takes the last stored
set and calls `IncrementProposerPriority(k)` once for the k heights since. That rescales and
centres the priorities once for all k heights, where the live state does so at every height, so
the priorities and the proposer can differ from the state CometBFT actually holds.

`rpc_rebuild_diverges` pins one such case. The generator tries seeds 1, 2, … with
PCG(22280, seed): a random committee of 4 to 12 members, 0 to 10 idle heights, one switch, then
up to 1,000 idle heights. It records the first seed where the rebuild of the set stored at
`change_step` differs from the live `next` at `step`, `blocks` heights later.
`bulk_priorities` and `bulk_proposer` are what `LoadValidators` returns there. The RPC is
exact only at heights CometBFT stored in full; never compare the live state against it
anywhere else.
