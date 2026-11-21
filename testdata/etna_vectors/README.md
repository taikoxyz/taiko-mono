# Etna vectors

`vectors.json` holds the values that the Etna L1 contracts, the Etna node and both proving guests
must agree on byte for byte: storage layout, ABI encodings and hashes, signature and key formats,
and the accept/reject cases of every boundary rule. Every implementation reads this one file
instead of carrying its own copies of the literals. Section numbers below refer to the Etna
specification; appendix A is the encodings and appendix B the L1 storage layout.

Schema version is `"9"`; clients refuse any other value. All integers are decimal strings, so
values above 2^53 survive every JSON parser. Hex values are `0x`-prefixed. Clients must decode every
input exactly: a decoder consumes all of its input and rejects trailing bytes, as the reject cases
below require.

Schema 9 follows the spec revision that commits a committee's set with one hash, counts registry
slots up to the highest occupied one, keys the lifetime forfeiture flag by bond id and lets anyone
write the switching start. Removed in schema 9: the set Merkle tree
(`committee_sets[].set_leaf_preimages`, `set_leaves` and `set_root`; the `ETNA_SET_LEAF_V1` and
`ETNA_SET_NODE` tags), `keys[].entry_key` and every use of an entry key,
`committee_config.inputs.s_min` (now `min_stake`), `deployment.origin_writer` and the
`registry_entries.roots` item of a list ending in an empty slot.

`governance_abi` encodes the calldata of delayed top-ups, the three-argument lifetime forfeiture
`forfeit(bondId, incidentId, validUntil)`, nonce/deadline-bound recovery whose exclusions are
strictly increasing bond ids (`uint256[]`, one word each) with its trailing `rules` argument,
explicit recovery invalidation, the rules schedule calls `scheduleRules(expectedGeneration, rules,
time)` and `scheduleStop(expectedGeneration, time)`, the start write `setOrigin(S)`, which takes only
the height, and the forced inclusion calls `saveForcedInclusion` and `sweepProtocolFees` (spec 4.4,
7.1, 8, 10, 10.1). `governance_events` gives each event's topics and data, including
`Forfeited(bondId, incidentId, balanceBefore, penalty)` (the bond id indexed), the unindexed
`RulesScheduleUpdated` (the packed slot-293 word) and `StartWritten`, and the Inbox's
`EtnaInitialized`, `Landed` (its three heights indexed), `ForcedInclusionSaved` (its queue index
indexed, then the raw transaction and the fee charged), `ProtocolFeesSwept` and `Recovered` (the new
generation indexed, then the excluded bond ids and the cleared forced inclusion indexes).
`view_abi` gives the calldata and return data of the registry lookups `bondForKey`, `bondInSlot` and
`slotOfBond`, where `(true, 0)` names bond 0 or slot 0 and `(false, 0)` is absence, the registry's
`forfeited(bondId)` flag and `minStake()`, the Inbox's `etnaStart()`, which returns (0, 0) before
the start write, and the Unzen Inbox's `proposeCutoff()`, 0 until a cutoff is installed.
`forfeitures` pins effective-first rounded-up deductions, including pending-only and uint256
boundary balances.

`validator_states` pins the ENC-A-29a.l encoding-only example: two entries per set,
negative `int64` priorities sign-extended to 32 bytes, and both stored proposer indexes.
Its 768-byte preimage hashes to
`0x368f341ba9eb8b6d6cadbd5b944daed7ed417b273d1257911a7fd18320f2a81b`.
Its synthetic keys do not establish CometBFT set ordering; that caveat applies to this example
only: `val_state_chains` holds states that CometBFT v0.40.0 computed from real keys (see
below). `app_hashes` pins ENC-A-29b.g: the three-word (96-byte) `ETNA_APP_HASH_V1` preimage of
EL hash `0x1111…11` and that validator-state hash, which hashes to
`0x381ceb5a317bd34b0b19b9972191a994c384b4873a3694cfd46cb155c7d8b451`. Only the app hash commits
the validator state: no cut leaf, slot 285 record or statement holds it (ENC-A-29a.m), and L1
never reads it.
LandInput has eight fields, slot 285 records have three words, cut leaves have four words, and
statements have 21 words (672 bytes). A landing carries one leaf for every height strictly
between p and h, so there is no landing grid.
The `0x06` envelope, the `0x64` extraData and all fixed storage slots remain unchanged.

## Sections

| Section               | Spec           | What it pins                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| --------------------- | -------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `deployment`          | 10, 11         | The deployment every other section uses: L1 chain id 1, L2 chain id 167001, Inbox proxy `0x1111…11`, registry `0x2222…22`, `L2_BLOCK_GAS_LIMIT` 45,000,000, the registry's immutable `min_stake` (250,000 TAIKO, `250000 × 10^18` base units: the registration minimum, the committee eligibility minimum and word five of `committee_config`; START-10-12 holds: `min_stake ≥ vp_unit` and `4096 × min_stake > 10^27`) and a new network: Etna start S = 0 (`etna_start`) and zero switch immutables (`unzen_inbox`, `etna_fork_time`).                                                                                                                                                                                                                                                                                                                                                                                                   |
| `keys`                | 4.1, A         | Six secp256k1 consensus keys (scalars 0xA1–0xA5 and the first scalar whose X has a zero top byte): the 33-byte compressed key, `ckPrefix`, `ckX`, `ckY` and `ckAddr = keccak256(ckX ‖ ckY)[12:]`.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| `key_decompression`   | 4.1, A         | Every key decoded from its own prefix and from the other one (the negated point, a different `ckAddr`), and the inputs registration rejects, each with a `reason`: X ≥ p (X is never reduced mod p), off-curve X, bad prefix, uncompressed (64 or 65 bytes), hybrid, trailing bytes, short, empty, the 66-byte ASCII hex text of a key (`textual`) and the single byte 0x00 (`identity`).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| `register_digests`    | 4.1, A         | The EIP-712 `Register(address owner)` domain separator, struct hash and digest at the deployment registry on L1 chain 1, and a proof of possession (65 bytes, V ∈ {0, 1}, low s) by every key for two owners.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| `pop_rejections`      | 4.1            | PoPs a registration by `owner` rejects although the key decodes: V of 27 or 2, high s, r or s zero, r = n, an r with no curve point, 64 or 66 bytes, and well-formed signatures bound to another owner, key, chain or verifying contract, or submitted with the other-parity key of their signer. `wrong_chain` is signed for chain id 167001 and `wrong_registry` with verifying contract `0x1111…11`.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| `committee_config`    | 4.3, 6.4, A, B | `committeeConfigHash` (Inbox slot 269): the seven input words (`ETNA_PARENT_ANCHOR_V1`, L2 chain id, registry, `vp_unit` 10^9, `min_stake` from `deployment`, `n_max` 128, `U` 3,600), the 224-byte preimage and the hash.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| `registry_entries`    | 4.1, 4.3, A, B | Entries in slots 0–4 from keys a1–a5 (entry i stakes (i + 1) × `min_stake`), their `ETNA_REG_ENTRY_V1` leaves, the leaf of an interior empty slot (`empty_slot`: slot 1, all-zero fields, a nonzero leaf, ENC-A-37 37.a) and the root of every fully occupied prefix (`roots`, counts 0–5). `checkpoints` and `bond_slots` list whole registry states; see the notes below.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| `committee_sets`      | 4.3, A         | Committees selected at snapshot 100 from registries holding the first 0, 1, 3 and 5 entries, in ascending set-key order: set keys, the whole `ETNA_SET_V1` setHash preimage (four head words, then the array length and four words per `SetMember(ckPrefix, ckX, effStake, assignedPower)`) and hash with `k = targetEpoch + 1`, total power and the five-field `ETNA_COMMITTEE_V1` record over setHash. `power` is the member's assignedPower. The empty committee is invalid and has no set hash or record.                                                                                                                                                                                                                                                                                                                                                                                                                              |
| `val_state_chains`    | 6.2, 8.4, A    | `valStateHash(x)` (ENC-A-29a) of the states stock CometBFT v0.40.0 holds after committing each height of five chains with real secp256k1eth keys: the genesis of generation 0 and of a recovery generation, single-height increments, switches at S(t) that add, remove and re-weight members, priority rescaling and centering at their bounds, proposer ties broken by address and both stored proposers; and 4096 members at `MaxTotalVotingPower`. See the notes below.                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| `cuts`                | 6.1, 6.3, A    | Cut leaves `keccak256(abi.encode(x, blockHash, cometHash, forcedHead))` (four words) for heights 0–18 of a fixed model (EL hash 100 + x, Comet hash 200 + x and 0 at x = 0, FI cursor x / 6), and `ETNA_LAND_CUTS_V1` cut hashes over the h − p − 1 leaves of the heights strictly between p and h: the empty list (`keccak256("")`) at h = p + 1 in generations 0 and 2, one leaf at h = p + 2, the 17 and 11 leaves of the two statements, and Etna start S = 1000 with p = 1000 and h = 1003, whose two leaves are at 1001 and 1002 (ENC-A-33.f).                                                                                                                                                                                                                                                                                                                                                                                       |
| `land_statements`     | 6.1, 6.2, A    | The 21-word (672-byte) `TAIKO_ETNA_LAND_V1` statement for a generation-0 landing from block 0 and a generation-1 landing from height 6.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| `land_abi`            | 6.1            | The `land(input, leaves, proof)` signature (eight-field LandInput), selector and complete calldata of the generation-1 statement with its 11 leaves.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| `chain_domains`       | 3.1, A         | `chainDomain` and the 48-byte CometBFT chain id `"etna-" + base64url_no_padding(chainDomain)` for generations 0, 1, 2 and 2^48 − 1 and for another Inbox.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| `votes`               | 4.1, A         | CometBFT vote sign bytes and secp256k1eth signatures by key a1: round 0 omitted, nil and partial block ids, a hash with an empty part set header (`12 00`), a zero timestamp (`2a 00`), negative and boundary timestamps (see below), the largest signable values and one- and two-byte length prefixes. `pairs` are double-sign evidence with the verdict at a given current generation: conflicts (including one from a historical generation and one between two backdated votes) and non-slashable pairs that differ in type, height, round or generation (each also with conflicting block ids), share a block id, or come from a future generation or another deployment.                                                                                                                                                                                                                                                            |
| `fi_eligibility`      | 7.2            | Raw forced-inclusion transactions at the deployment's L2 chain id and block gas limit, each `eligible` or not. See the notes below.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| `extra_data`          | 3.2, A         | The 13-byte `extraData = 0x64 ‖ uint48_be(generation) ‖ uint48_be(anchorNumber)`.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| `packed_words`        | B              | Every packed storage word (Inbox slots 272, 281, 282 and 293, the second word of a slot-280 entry and the first word of a slot-285 record; the registry's first checkpoint word and third entry word) with an ordinary and an all-max item. Slot 293 packs four 48-bit fields, so its bits from 192 up are zero (STOR-B-24).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| `origin_words`        | 8.4, B         | Slot-290 origins `(startHeight, l1BlockNumber, l1Timestamp)`, three full words each. The items are encoding-only.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| `layout`              | A, B           | For the Inbox: the named slots, including the slot-293 rules schedule, the reserved slots, the packing table, the initialized status (3), the anchor witness slots in proof order (268, 270, 271, 281, 293) and the mapping slots of forced inclusion entries, landings and origins. For the registry: the ERC-7201 base R of `taiko.etna.registry`, the checkpoint (R) and slot-indexed entry (R + 1) array slots, the packing table, the slots a committee witness proves for a snapshot, and the bond-id-indexed `owners`, `exit_confirmations`, `top_ups` and `forfeitures` namespaces (bond ids 0 and 4096: ids are not slots and are not bounded by 4096).                                                                                                                                                                                                                                                                           |
| `appendix_a_examples` | A              | Every literal hash and byte string of the spec's appendix A vectors, recomputed: `enc_a_10b_a` (mixHash), `enc_a_23b_a`, `enc_a_23c_a`, `enc_a_23c_b` and `enc_a_23d_f` (blobs), `enc_a_29a_n`, `enc_a_29a_o` and `enc_a_29a_p` (validator-set arithmetic on sets with given priorities, members from `val_state_chains.keys`: the rescaled and centred priorities, the final set and its proposer, and for 29a.p the update with the new member's starting priority −19; computed with `valset_model.py` and checked against stock CometBFT v0.40.0), `enc_a_36_a`, `enc_a_37_a`, `enc_a_37_i`, `enc_a_37_j` (the rejected dynamic-string tag), `enc_a_38_h`, `enc_a_39_a`, `enc_a_39a_a`, `enc_a_42_a` and `enc_a_45_g`, and `dynamic_tag_rejects`: for each domain-tagged hash, the preimage with its tag encoded as a dynamic string and the hash it gives instead (ENC-A-5). 29a.l and 29b.g are `validator_states` and `app_hashes`. |

### Registry states and committee sets

- A registry checkpoint's `count` is 0 when every slot is empty and otherwise 1 + the highest
  occupied slot, occupied slots with zero balance included (STAKE-4.1-36), so it shrinks on
  withdrawal and a nonempty list always ends in an occupied slot (COMM-4.3-2). `entriesRoot` is 0
  for count 0; otherwise leaf j is `regLeaf(j)` for every j below count, an interior empty slot
  hashing its all-zero fields under its own slot number (a nonzero leaf), and the list is padded on
  the right with `bytes32(0)` to the smallest power of two ≥ count; one leaf is its own root
  (ENC-A-38).
- A listed state has `count`, `slots` (every slot below count in order: `slot`, `occupied` and the
  five entry fields, all zero for an empty slot), `leaves` and `entries_root`.
- `checkpoints` is the history of a three-slot registry, one checkpoint per listed L1 block
  (`l1_block`, `count`, `entries_root` and the packed first checkpoint word `checkpoint_word1`):
  `three_bonds` (slots 0–2 held), `slot_1_withdrawn` (ENC-A-38 38.h and COMM-4.3-2 2.d: count 3,
  root K(K(L0, Z1), K(L2, 0)); `wrong_roots` gives the roots of 38.i and 2.e: a zero word for Z1,
  the zero-field leaf of slot 3 as padding, slot 2 compacted to slot 1 and slot 1 omitted),
  `slot_2_zero_balance` (36.f: a slashed, zero-balance bond still in slot 2 keeps count 3),
  `slot_2_withdrawn` (36.g: count 1) and `slot_0_withdrawn` (36.g: count 0, root 0). Earlier
  checkpoints keep their own count and root. Bond 0's exit request, which also writes a
  checkpoint, is not listed.
- `bond_slots` pins `regLeaf` indexed by the slot, not the bond id: bond 4096 in slot 7 of a
  registry whose slots 0–7 are held and every higher slot is empty (ENC-A-37 37.e, count 8; slots
  5 and 6 hold keys 0xA6 and 0xA7) and bond 2 in slot 0 beside bond 1 in slot 1 (37.g, count 2),
  each with the wrong leaf a bond-id index gives (`bond_id_leaf`) and its whole state.
- A committee's set is one hash, `setHash = keccak256(abi.encode(bytes32("ETNA_SET_V1"), l2ChainId,
k, SetMember[]))` with the members in ascending set-key order and `k = targetEpoch + 1`
  (ENC-A-39a, ENC-A-42a), and the record commits setHash (ENC-A-42). No rule proves a single
  member against it, so there are no set leaves or nodes. The committee examples' members are
  eligible at snapshot 100 (`effStake ≥ min_stake`, COMM-4.3-3), so selection keeps every entry.

### Validator-state chains

`val_state_chains` is what a client must reproduce for SYNC-9-5c and DATA-5.4-3: the validator
state after each height, from a generation's genesis on, applying the validator updates that
FinalizeBlock returns. Its hash enters only the app hash (`app_hashes`); no landing carries it.

- `keys` are c1–c12 (private keys 0xC1–0xCC) with `ck_prefix`, `ck_x`, `ck_y` and the
  secp256k1eth address `ck_addr` that orders a set. A set row is
  `[key, votingPower, proposerPriority]` in CometBFT's order (power descending, then `ck_addr`
  ascending); its ValEntry is `(ck_prefix, ck_x, votingPower, proposerPriority)` of that key.
  `current_proposer` and `next_proposer` are indexes into the rows.
- A chain has `genesis` (the validators of the genesis at `start_height`, whose initial height is
  `start_height + 1`), `switches`, and one state per height through `end_height` with both sets,
  both stored proposers and `hash`. `start_preimage` is the preimage at `start_height`; the other
  preimages follow from the rows and `keys`.
- FinalizeBlock returns a switch at `height` = S(t) = t·L − 1 (L is `epoch_length`; H(t) =
  1 + t·L counts from block 0) as `changes`: a joining member at its power, a leaving member at 0,
  a re-weighted member at its new power. It changes only `next` at S(t); `current` at S(t) + 1
  holds the new committee, which first signs `activation_height` = H(t) = S(t) + 2
  (COMM-4.3-13). Sending the whole new committee instead, unchanged members at their power, gives
  the same state, because CometBFT keeps an unchanged member's priority; `valgen/` checks this at
  every height.
- `gen0` is generation 0 from S = 0 with L = 7, heights 0–48, switching at 6 (add), 13 (remove),
  20 (re-weight), 27 (all three), 34 (add), 41 (remove the largest member, add a small one: the
  update rescales) and 48. `gen1` is the recovery generation from c = 48 (8.4): a new genesis at
  48, heights 48–60. Generation 0's update returned at 48 is discarded with its state, and the
  next switch is S(8) = 55. `bounds_a`, `bounds_b` and `bounds_c` (L = 3) reach the
  priority-window bounds: a spread of exactly 2·total (no rescale) and of 2·total + 1 (rescale
  by 2), each inside `UpdateWithChangeSet` and inside `IncrementProposerPriority`, the latter
  also at a height without an update, and a centered sum of −1 over four members.
- `events` mark where a chain reaches these cases, as `valset_model.py` replays it. `rescale` is
  a spread at or above `diff_max` = 2·total, with `fires`, `ratio` and the `truncated` members
  whose negative priority Go's division rounds toward zero. `center` is a negative sum that is not
  a multiple of the member count; the shift is the floor of the average (`big.Int.Div`), not the
  truncated quotient. `tie` is a shared highest priority; the lowest address becomes the
  proposer. `step` is `genesis` (the increment inside `NewValidatorSet`, giving `current`),
  `genesis_next` (the further increment giving `next`), `update` (inside `UpdateWithChangeSet`)
  or `increment` (`IncrementProposerPriority`).
- Every stored set's priorities sum to between 0 and n − 1. The stored proposer is the member
  the last increment decremented, usually not the highest priority: read it, never recompute it.
- `max_committee` is 4096 members at `MaxTotalVotingPower` = (2^63 − 1) / 8. Member i (key mi)
  has private key 0x10000 + i and power 2^48 + (i mod 64) − 32; member 4095 takes the rest of the
  total, 2^48 + 2078, so 64 power classes each order by address. It lists the hash at genesis
  and one height later, both proposers, the first and last three rows of each set and the
  preimage size (1,048,832 bytes), not all 16,384 rows: those would add more than 1 MB to a file
  that every Etna Solidity test loads. Rebuild the sets from the rules and compare the hash; the
  rows shown and the proposers locate a mismatch.

`valgen/` produces every state with CometBFT's own code: `state.MakeGenesisState` at a chain's
start (state/state.go:344-345: `NewValidatorSet` and `CopyIncrementProposerPriority(1)`), and
`BlockExecutor.ApplyVerifiedBlock` at each later height, which runs an ABCI app whose
FinalizeBlock returns the switch's updates and applies them through the unexported `updateState`
(state/execution.go:737-804). Nothing that produces an output is reimplemented. As a check,
`valgen/` also recomputes each height from `updateState`'s validator lines with exported
functions (`Copy`, `UpdateWithChangeSet`, `IncrementProposerPriority`; execution.go:746-760 and
795-796) and requires the same sets. `valset_model.py` is a separate standard-library model of
that arithmetic, written from types/validator_set.go and types/validator.go: generation stops if
it differs from CometBFT at any height, and `test_vectors.py` replays every chain with it.

### Forced-inclusion eligibility

- Only `eligible` is normative. `rule` is a diagnostic label naming the one rule an ineligible
  case breaks (`noncanonical`, `type`, `chain_id`, `signature`, `width` or `gas_limit`); each such
  case breaks only that rule (`gas_2_64` is also above the gas limit), so an implementation that
  skips the rule accepts it.
- Eligibility ignores fees: `eip1559_zero_fee` and `eip1559_tip_above_max_fee` are eligible. A
  type-4 transaction with an empty authorization list is eligible, and an authorization tuple only
  needs the EIP-7702 field widths.
- `s_half_n` (s = ⌊n/2⌋, the largest low s) is the one eligible case not signed by the FI sender:
  it recovers `0x3658d3acd1c0ac738ee3535382921f5ba72d6b8e`.
- go-ethereum v1.15.5 accepts some width-violating cases (`fee_2_128`, `tip_2_128`,
  `legacy_gas_price_2_128`, `eip2930_gas_price_2_128`, `eip7702_fee_2_128`, `value_33_bytes`):
  it reads fees and value as unbounded integers. Implementations must check every fee field and
  the value explicitly instead of relying on an EL decoder.

### Vote hash presence and ABI

`Vote.blockHash` and `Vote.partsHash` are raw `bytes`, either empty (`"0x"`) or exactly 32
bytes. A present all-zero hash is encoded unchanged. Only two empty hashes with total 0 make a
nil BlockID. The zero-hash cases include complete non-nil BlockIDs and partial BlockIDs with
total 0, including either or both hashes present. `votegen/` passes these raw fields to stock
CometBFT without normalization; the independent Python encoder and Solidity tests compare the
resulting sign bytes and signatures. The 23 earlier sign-byte strings and signatures are
unchanged; their absent hash inputs now use `"0x"` explicitly.

This changes the `slashDoubleSign` tuple and selector. `votes.slash_abi` pins the signature,
selector and calldata of the zero-parts-hash conflict. Clients must refresh the registry ABI and
read this schema (9) before submitting evidence.

### Vote timestamps

- CometBFT v0.40.0 signs and accepts a vote with any timestamp protobuf's `Timestamp` can hold,
  0001-01-01T00:00:00Z (−62,135,596,800 s) up to 9999-12-31T23:59:59Z (253,402,300,799 s),
  negative (pre-1970) seconds included; each vote carries its own, so both votes of a double sign
  can be backdated. `negative_timestamp`, `min_timestamp`, `max_timestamp_seconds` and the
  `backdated_conflict` pair cover this.
- `timestampSeconds` is the signed decimal int64 (e.g. `"-1"`); `timestampSecondsU64` is its
  64-bit two's-complement pattern (seconds mod 2^64, e.g. `"18446744073709551615"`), the value
  the registry's `uint64 Vote.timestampSeconds` carries. The two always agree.
- The sign bytes write the seconds as protobuf's int64 varint, which is the uvarint of the
  two's-complement pattern: a negative second takes ten bytes (−1 is
  `ff ff ff ff ff ff ff ff ff 01`).

## Regenerating

Run from the repository root, with Foundry's `cast`, Go and the workspace's dependencies
installed (the output is formatted by running the repository root's `node_modules/.bin/prettier`
directly; generation stops if it is missing):

```bash
python3 -I testdata/etna_vectors/generate.py
```

`generate.py` holds the inputs, the packing table and the storage slot numbers, written from
appendices A and B. Every ABI encoding, hash and storage slot is computed by `cast`, independently
of the contracts and of the node; a maximum-committee validator set is encoded in slices, because
Linux limits one command-line argument to 128 KiB. Every literal of appendix A's vectors must
reproduce, or generation stops. Three Go modules, each in its own directory and never imported by
the root module, are run with `go run` (a `GOFLAGS` in the environment, such as `-p=2`, is kept):

- `votegen/` signs every vote with stock CometBFT v0.40.0 (`types.VoteSignBytes` and the
  secp256k1eth key type). Generation stops if any sign-byte string differs from a separate Python
  encoder written from appendix A; neither side is adjusted to match the other.
- `ficheck/` checks the written `fi_eligibility` cases against go-ethereum v1.15.5.
- `valgen/` computes the `val_state_chains` states with stock CometBFT v0.40.0 (above), and the
  29a.n–p cases with `ValidatorSet.UpdateWithChangeSet` and `IncrementProposerPriority` on sets
  built with the given priorities. Generation stops if any state differs from `valset_model.py`,
  or any preimage or hash from `cast abi-encode` and `cast keccak` of its rows.

Regeneration is deterministic: two runs produce identical bytes. The structural tests need only
the Python standard library (plus `valset_model.py` and a Keccak-256 of their own for the
validator-state chains) and run in the protocol CI:

```bash
python3 -m unittest discover -s testdata/etna_vectors -p 'test_vectors.py' -v
```

## Consumers

- Contracts (`packages/protocol`, profile `layer1`; `foundry.toml` grants read access to this
  directory): `test/layer1/etna/LibEtnaVectors.sol` loads the file for the Etna Solidity tests.
  `EtnaVectors.t.sol` checks the Inbox and registry layout through their views and rebuilds every
  appendix A encoding; the library and registry tests check their own sections.
- The Etna node and guests read the same file. The L1 contracts hold no validator-state hash, so
  `validator_states`, `app_hashes` and `val_state_chains` serve the node.
