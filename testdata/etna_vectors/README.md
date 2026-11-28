# Etna vectors

`vectors.json` holds the values that the Etna Inbox on L1, the `EtnaStaking` contract on L2, the
Etna node and both proving guests must agree on byte for byte: storage layout, ABI encodings and hashes, signature and key formats,
and the accept/reject cases of every boundary rule. Every implementation reads this one file
instead of carrying its own copies of the literals. Section numbers below refer to the Etna
specification; appendix A is the encodings and appendix B the storage layout (the Inbox on L1,
the staking contract on L2).

Schema version is `"11"`; clients refuse any other value. All integers are decimal strings, so
values above 2^53 survive every JSON parser. Hex values are `0x`-prefixed. JSON null appears in two
fields only, both under [Staking and the fallback key set](#staking-and-the-fallback-key-set). Clients must decode every
input exactly: a decoder consumes all of its input and rejects trailing bytes, as the reject cases
below require.

Schema 11 follows the spec revision that releases a seat after `missReleaseLimit` consecutive
misses and no longer resets the miss count at a penalty. Added in schema 11:
`deployment.miss_release_limit` and `on_block_start.deployment.miss_release_limit`, which an
`on_block_start` case's `overrides` may set. Changed: a penalized seat keeps its count in
`expect.miss_counts`, prior calls may take penalties (never a release), `expect.penalty_total` is
what the call itself sends, and six cases cover the repeated penalty and the release.

Schema 10 follows the spec revision that moves staking to the L2 `EtnaStaking` contract, which the
EL calls at the start of every block, and gives the Inbox a fallback key set and a
`minTotalStake` that the DAO sets. Removed in schema 10: the registry (`registry_entries`,
`layout.registry`, `deployment.registry` and the registry's packed words), committee selection
(`committee_sets`), `committee_config` (now `config`: four words over the L2 chain id, the staking
proxy and U), the delayed top-up activation (`activate_top_up`, `top_up_activated`), recovery
exclusions, the committee snapshot in statements and `LandInput`, and the Inbox slot names
`genesis_committee_record_hash` (278), `genesis_cutoff` (279) and `active_committee_snapshot`
(284). `land_statements[].inputs.committee_config_hash` and
`layout.inbox.slots.committee_config_hash` are now `config_hash`. Added in schema 10:
`fallback_keys`, `staking_layout`, `miss_bitmap`, `candidate` and `on_block_start` (see
[Staking and the fallback key set](#staking-and-the-fallback-key-set)). `val_state_chains` has no
epochs: FinalizeBlock may return validator updates at any height, so `epoch_length` and the
updates' `epoch` are gone; two chains start from a genesis of fallback keys at power 1, and
`max_committee` is 128 members, the most that any set that signs a block has.

`governance_abi` encodes calldata, each entry labelled with its `contract` (`inbox` or `staking`):
the Inbox's nonce/deadline-bound recovery `recover(expectedGeneration, expectedC,
expectedRecoveryNonce, validUntil, fiToClear, rules)`, explicit recovery invalidation, the rules
schedule calls `scheduleRules(expectedGeneration, rules, time)` and
`scheduleStop(expectedGeneration, time)`, the start write `setOrigin(S)`, which only the origin
multisig sends and which takes only the height, the forced inclusion calls `saveForcedInclusion`
and `sweepProtocolFees`, and the DAO's `setFallbackKeys` and `setMinTotalStake`; and the staking
contract's `register`, `topUp`,
`requestExit`, `withdraw`, the three-argument lifetime forfeiture `forfeit(bondId, incidentId,
validUntil)`, the block-start call `onBlockStart(generation, missBitmap)` and `slashDoubleSign`
(the `votes.slash_abi` call) (spec 4.1, 4.4, 7.1, 8, 10, 10.1). `governance_events` gives each
event's contract, topics and data: the Inbox's `FallbackKeysUpdated` (the list's hash indexed, the
stored list as data), `MinTotalStakeUpdated`, `RecoveryNonceInvalidated`, the unindexed
`RulesScheduleUpdated` (the packed slot-293 word) and `StartWritten`, `EtnaInitialized` (the config
hash, the staking proxy and U), `Landed` (its three heights indexed), `ForcedInclusionSaved` (its
queue index indexed, then the raw transaction and the fee charged), `ProtocolFeesSwept` and
`Recovered` (the new generation indexed, then c, the L1 block number and timestamp, the new
origin's fallback key hash and the cleared forced inclusion indexes); and the staking contract's
`TopUpDeposited(bondId, amount)` and `Forfeited(bondId, incidentId, balanceBefore, penalty)` (the
bond id indexed). `view_abi` gives the calldata and return data of the Inbox's `configHash()`,
`etnaStaking()`, `unsettledLimit()`, `getFallbackKeys()`, `fallbackKeysHash()`, `minTotalStake()`
and `etnaStart()`, which returns (0, 0) before the start write; the Unzen Inbox's
`proposeCutoff()` (contract `unzen_inbox`), 0 until a cutoff is installed; and the staking
contract's lookups `bondForKey`, `seatOfBond` and `bondInSeat`, where `(true, 0)` names bond 0 or
seat 0 and `(false, 0)` is absence, `snapshot()` (an encoding-only example: its powers are far
below what a stake of at least `min_stake` gives), `registerDigest(owner)`, the lifetime
`forfeited(bondId)` flag and `minStake()`. `forfeitures` pins the rounded-up deduction
`ceil(balance × forfeitBps / 10,000)` from the bond's whole principal, including uint256 boundary
balances.

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
LandInput has seven fields, slot 285 records have three words, cut leaves have four words, and
statements have 19 words (608 bytes). A landing carries one leaf for every height strictly
between p and h, so there is no landing grid.
The `0x06` envelope is unchanged; extraData is 29 bytes and ends with the block's missBitmap.

## Sections

| Section               | Spec          | What it pins                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| --------------------- | ------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `deployment`          | 10, 11        | The deployment every other section uses: L1 chain id 1, L2 chain id 167001, Inbox proxy `0x1111…11`, the `EtnaStaking` proxy `0x1670…010003` and the bridged TAIKO token `0x1670…000007` (chain 167001's genesis predeploys), `L2_BLOCK_GAS_LIMIT` 45,000,000, the staking contract's immutables (`min_stake` 7,812,500 TAIKO, `7812500 × 10^18` base units; `vp_unit` 10^9; `n_max` 128; `miss_limit` 3,600 and `miss_release_limit` 10,800, the client test devnet's values, not the references 21,600 and 64,800; `miss_slash_bps`, `slash_bounty_bps` and `forfeit_bps` 1,000; `withdrawal_delay` 302,402 L2 blocks, U + 2 + the evidence window), U (`unsettled_limit`) 151,200, the evidence window (`evidence_window_blocks`) 151,200, and a new network: Etna start S = 0 (`etna_start`) and zero switch immutables (`unzen_inbox`, `etna_fork_time`).                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| `keys`                | 4.1, A        | Six secp256k1 consensus keys (scalars 0xA1–0xA5 and the first scalar whose X has a zero top byte): the 33-byte compressed key, `ckPrefix`, `ckX`, `ckY` and `ckAddr = keccak256(ckX ‖ ckY)[12:]`.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| `key_decompression`   | 4.1, A        | Every key decoded from its own prefix and from the other one (the negated point, a different `ckAddr`), and the inputs registration rejects, each with a `reason`: X ≥ p (X is never reduced mod p), off-curve X, bad prefix, uncompressed (64 or 65 bytes), hybrid, trailing bytes, short, empty, the 66-byte ASCII hex text of a key (`textual`) and the single byte 0x00 (`identity`).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| `register_digests`    | 4.1, A        | The EIP-712 `Register(address owner)` domain separator (name `EtnaStaking`, version 1, the L2 chain id and the staking proxy as verifying contract), struct hash and digest, and a proof of possession (65 bytes, V ∈ {0, 1}, low s) by every key for two owners.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| `pop_rejections`      | 4.1           | PoPs a registration by `owner` rejects although the key decodes: V of 27 or 2, high s, r or s zero, r = n, an r with no curve point, 64 or 66 bytes, and well-formed signatures bound to another owner, key, chain or verifying contract, or submitted with the other-parity key of their signer. `wrong_chain` is signed for the L1 chain id 1 and `wrong_registry` with the Inbox `0x1111…11` as verifying contract.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| `config`              | 6.4, 10, A, B | `configHash` (Inbox slot 269): the four input words (`ETNA_CONFIG_V1`, L2 chain id, the staking proxy, U 151,200), the 128-byte preimage and the hash.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| `val_state_chains`    | 6.2, 8.4, A   | `valStateHash(x)` (appendix A) of the states stock CometBFT v0.40.0 holds after committing each height of seven chains with real secp256k1eth keys: the genesis of generation 0 and of a recovery generation, both from fallback keys at power 1 and from members of unequal powers, single-height increments, validator updates returned at any height that add, remove and re-weight members and first sign two heights later, switches between the candidate and the fallback key set that replace the whole set in one update list, priority rescaling and centering at their bounds, proposer ties broken by address and both stored proposers; and 128 members, the most that any set that signs a block has, at `MaxTotalVotingPower`. See the notes below.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| `cuts`                | 6.1, 6.3, A   | Cut leaves `keccak256(abi.encode(x, blockHash, cometHash, forcedHead))` (four words) for heights 0–18 of a fixed model (EL hash 100 + x, Comet hash 200 + x and 0 at x = 0, FI cursor x / 6), and `ETNA_LAND_CUTS_V1` cut hashes over the h − p − 1 leaves of the heights strictly between p and h: the empty list (`keccak256("")`) at h = p + 1 in generations 0 and 2, one leaf at h = p + 2, the 17 and 11 leaves of the two statements, and Etna start S = 1000 with p = 1000 and h = 1003, whose two leaves are at 1001 and 1002.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| `land_statements`     | 6.1, 6.2, A   | The 19-word (608-byte) `TAIKO_ETNA_LAND_V1` statement, with the config hash ninth and no staking address or committee snapshot, for a generation-0 landing from block 0 and a generation-1 landing from height 6.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| `land_abi`            | 6.1           | The `land(input, leaves, proof)` signature (seven-field LandInput), selector `0x5185fd7a` and complete calldata of the generation-1 statement with its 11 leaves.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| `chain_domains`       | 3.1, A        | `chainDomain` and the 48-byte CometBFT chain id `"etna-" + base64url_no_padding(chainDomain)` for generations 0, 1, 2 and 2^48 − 1 and for another Inbox.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| `votes`               | 4.1, A        | CometBFT vote sign bytes and secp256k1eth signatures by key a1: round 0 omitted, nil and partial block ids, a hash with an empty part set header (`12 00`), a zero timestamp (`2a 00`), negative and boundary timestamps (see below), the largest signable values and one- and two-byte length prefixes. `pairs` are double-sign evidence with the verdict at a given current generation: conflicts (including one from a historical generation and one between two backdated votes) and non-slashable pairs that differ in type, height, round or generation (each also with conflicting block ids), share a block id, or come from a future generation or another deployment.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| `fi_eligibility`      | 7.2           | Raw forced-inclusion transactions at the deployment's L2 chain id and block gas limit, each `eligible` or not. See the notes below.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| `extra_data`          | 3.2, 4.2, A   | The 29-byte `extraData = 0x64 ‖ uint48_be(generation) ‖ uint48_be(anchorNumber) ‖ uint128_be(missBitmap)`, where seat s is bit s of missBitmap (seat 0 the low bit of the last byte, seat 127 the high bit of byte 13), and the 68-byte block-start calldata `onBlockStart(generation, missBitmap)` (selector `0xea987592`, then one word each): all zero, generation 1 with anchor 258 and missBitmap 2^127 + 1, every field at its maximum, and seat 0 and seat 127 alone.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| `packed_words`        | B             | Every packed storage word (Inbox slots 272, 281, 282 and 293, the second word of a slot-280 entry and the first word of a slot-285 record; the staking contract's key-to-seat value `[holdsSeat 8 bits, seat 8 bits]` and the second word of a snapshot seat record `[ckPrefix 8 bits, power 64 bits]`) with an ordinary and an all-max item (ckPrefix 3, holdsSeat 1, seat 127, every other field all ones). Slot 272 packs `[genesisHeight, L1_0]`; slot 293 packs four 48-bit fields, so its bits from 192 up are zero.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| `origin_words`        | 8.4, B        | Slot-290 origins `(startHeight, l1BlockNumber, l1Timestamp, fallbackKeysHash)`, four full words each; the fourth is the value of slot 278 when the record is written. The items are encoding-only.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| `layout`              | A, B          | For the Inbox: the named slots (269 the config hash, 278 the fallback key hash, 279 `minTotalStake`, 293 the rules schedule), the reserved slots (283, 284, 286–289 and 291), the packing table, the initialized status (3), the anchor witness slots in proof order (268, 270, 271, 278, 279, 281, 293) and the mapping slots of forced inclusion entries, landings and four-word origins.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| `fallback_keys`       | 4.3, A        | The DAO's fallback key lists under `ETNA_FALLBACK_KEYS_V1` (Ki is the key of private key i): `accepted` lists with their preimage (3 + 2n words), `fallbackKeysHash`, `FallbackKeysUpdated` event (topic0, the hash as topic 1, the list as data) and the validators they sign as (each key's secp256k1eth address, power 1): [K1] and [K1, K2] (the spec's hashes), [K3, K9] (prefix 0x02 before 0x03 although K9's X is smaller) and the 128 keys of private keys 1–128 (an 8,288-byte preimage, 258 words of event data); `rejected` lists with the condition each breaks: `count` (empty, 129 keys), `order` ([K2, K1], [K1, K1], [K9, K3]) or `key` (prefix 0x04, X = p, X = 5).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| `staking_layout`      | 4.1, 4.2, B   | The staking contract's words that nodes and guests read: the ERC-7201 base T of `taiko.etna.staking`, `snapshotHeight` at T, `snapshotTotalStake` at T + 1, the key-to-seat mapping at T + 2 with the elements of K1, K2 and keys a1–a4, snapshot seat records 0, 5 and 127 at T + 3 + 2s and T + 4 + 2s, how key-to-seat values decode (`seat` is null for no seat), record second words `[ckPrefix 8 bits, power 64 bits]`, the proxy's EIP-1967 implementation slot and `exitHeight`'s no-exit value 2^48 − 1.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| `miss_bitmap`         | 3.4, 4.2      | The missBitmap a block sets from the validators of the set that signs its parent. See the notes below.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| `candidate`           | 4.3, B        | Whether the candidate decided at H is usable and the set that signs H + 2. See the notes below.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| `on_block_start`      | 4.1, 4.2      | `onBlockStart` on a fresh staking contract and the state it leaves. See the notes below.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| `appendix_a_examples` | A             | Every literal hash and byte string of the spec's appendix A vectors, recomputed: `enc_a_10_f` and `enc_a_10_h` (extraData), `enc_a_10b_a` (mixHash), `enc_a_10c_a` and `enc_a_10c_b` (the missBitmap bit order), `enc_a_10d_a` and `enc_a_10d_b` (the block-start calldata and selector), `enc_a_23b_a`, `enc_a_23c_a`, `enc_a_23c_b` and `enc_a_23d_f` (blobs), `enc_a_29a_n`, `enc_a_29a_o` and `enc_a_29a_p` (validator-set arithmetic on sets with given priorities, members from `val_state_chains.keys`: the rescaled and centred priorities, the final set and its proposer, and for 29a.p the update with the new member's starting priority −19; computed with `valset_model.py` and checked against stock CometBFT v0.40.0), `enc_a_36_a` and `enc_a_36_f` (the config hash of L2 chain id 167000, staking `0x1111…11` and U = 151,200, and its rejected dynamic-string twin), `enc_a_36a_a`, `enc_a_36a_b` and `enc_a_36a_g` (the fallback key hashes of [K1] and [K1, K2], K1 and K2 the keys of private keys 1 and 2, and the rejected dynamic-string twin of the first) and `enc_a_45_g`, and `dynamic_tag_rejects`: for each domain-tagged hash, the preimage with its tag encoded as a dynamic string and the hash it gives instead. 29a.l and 29b.g are `validator_states` and `app_hashes`. |

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
  `start_height + 1`; they sign `start_height + 1` and `start_height + 2`), `switches`, and one
  state per height through `end_height` with both sets, both stored proposers and `hash`.
  `start_preimage` is the preimage at `start_height`; the other preimages follow from the rows and
  `keys`.
- FinalizeBlock(H) may return validator updates at any height H after `start_height`. Each is a
  `switches` row with `height` = H and `changes`, the difference between the set that signs H + 2
  and the set that signs H + 1: a joining member at its power, a leaving member at 0, a
  re-weighted member at its new power. A member whose power stays the same is not listed. The
  update changes only `next` at H; `current` at H + 1 holds the new set, which first signs
  `activation_height` = H + 2 (4.3). Sending the whole new set instead, unchanged members at their
  power, gives the same state, because CometBFT keeps an unchanged member's priority; `valgen/`
  checks this at every height. Every `current` and `next` has 1 to 128 members.
- `gen0` is generation 0 from height 0, heights 0–48, with updates at 6 (add), 13 (remove), 20
  (re-weight), 27 (all three), 34 (add), 41 (remove the largest member, add a small one: the
  update rescales) and 48. `gen1` is the recovery generation from c = 48 (8.4): a new genesis at
  48, heights 48–60. Generation 0's update returned at 48 is discarded with its state, and the
  next update is returned at 55. Both start from members of unequal powers, which exercise
  CometBFT's arithmetic; an Etna genesis gives each fallback key power 1. `bounds_a`, `bounds_b`
  and `bounds_c` reach the priority-window bounds: a spread of exactly 2·total (no rescale) and
  of 2·total + 1 (rescale by 2), each inside `UpdateWithChangeSet` and inside
  `IncrementProposerPriority`, the latter also at a height without an update, and a centered sum
  of −1 over four members.
- `fallback_genesis_to_candidate` is generation 0 as Etna derives it (4.3): the genesis is the
  fallback key set c1–c4, each at power 1, which signs 1 and 2. The update returned at 1 removes
  every fallback key and adds a usable candidate (c5, c6 and c7 at 30, 20 and 10), which signs
  from 3; c6 is re-weighted at 4 and c7 leaves at 6; at 8 one update removes the candidate and
  restores the fallback key set at power 1, which signs from 10. Each switch between the
  candidate and the fallback key set replaces the whole set through one update list.
  `recovery_origin_keys` is generation 1 from a governance recovery at c = 10 (8.4): its genesis
  is the new origin's fallback keys c8 and c9 at power 1, which sign 11 and 12, and the update
  returned at 11 replaces them with the candidate c5 at 30, which signs from 13.
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
- `max_committee` is 128 members, the most that any set that signs a block has, at
  `MaxTotalVotingPower` = (2^63 − 1) / 8. Member i (key mi) has private key 0x10000 + i and power
  2^48 + (i mod 64) − 32; member 127 takes the rest of the total, 3969·2^48 + 94, so 63 pairs of
  equal power each order by address. It lists the hash at genesis and one height later, both
  proposers, the first and last three rows of each set and the preimage size (33,024 bytes), not
  all 512 rows: the hash pins every row, and the family keeps the sampled shape it had before.
  Rebuild the sets from the rules and compare the hash; the rows shown and the proposers locate a
  mismatch.

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

`votes.slash_abi` pins the staking contract's `slashDoubleSign` signature, selector and
calldata of the zero-parts-hash conflict; `governance_abi.slash_double_sign` repeats it.

### Vote timestamps

- CometBFT v0.40.0 signs and accepts a vote with any timestamp protobuf's `Timestamp` can hold,
  0001-01-01T00:00:00Z (−62,135,596,800 s) up to 9999-12-31T23:59:59Z (253,402,300,799 s),
  negative (pre-1970) seconds included; each vote carries its own, so both votes of a double sign
  can be backdated. `negative_timestamp`, `min_timestamp`, `max_timestamp_seconds` and the
  `backdated_conflict` pair cover this.
- `timestampSeconds` is the signed decimal int64 (e.g. `"-1"`); `timestampSecondsU64` is its
  64-bit two's-complement pattern (seconds mod 2^64, e.g. `"18446744073709551615"`), the value
  the staking contract's `uint64 Vote.timestampSeconds` carries. The two always agree.
- The sign bytes write the seconds as protobuf's int64 varint, which is the uvarint of the
  two's-complement pattern: a negative second takes ten bytes (−1 is
  `ff ff ff ff ff ff ff ff ff 01`).

### Staking and the fallback key set

- `miss_bitmap`: each case lists the validators of the set that signs the parent, candidate members
  or fallback keys, with `ck_addr`, `block_id_flag` in the block's LastCommit (1 absent, 2 commit,
  3 nil) and `key_seat_word`, the key-to-seat value of that address in the parent's post-state. A
  validator is missing unless its flag is 2. A word gives seat s only when holdsSeat (bits 0–7) is
  1, seat (bits 8–15) is below 128 and every higher bit is 0; bit s is 1 exactly when a missing
  validator has seat s. A block with `first_block_of_generation` has no LastCommit and sets 0,
  whatever its validators show. The bits of the missing validators are OR-ed: a reader that assigns
  each validator's bit instead fails `two_seats`, and one that toggles it fails
  `two_addresses_one_seat_both_missing`. The cases: every validator committed; an absent validator
  in seat 5, a nil one in seat 0; two missing validators in seats 0 and 3 (bitmap 9); seat 127; the
  fallback key set signing the parent, with a missing key that no bond uses (word 0) and one that is
  also the key of a bond in seat 7; a key whose bond left its seat in the parent (word 0); words
  that are not well formed (0x0502, 0x8001, 0x10501); two addresses that map to seat 3, one missing
  and then both (the bit is set once); seat 100, set whatever n_max is (with n_max ≤ 100,
  `onBlockStart` then ignores it); and a generation's first block.
- `candidate`: H = 100, the members are keys a1–a3 (in `power_sum_wraps` and `full_128`, the keys
  of private keys 0x200–0x27f) and the fallback key set is [K1, K2]. `records` lists the nonzero snapshot seat
  records; every other record is zero. The candidate is usable exactly when `min_total_stake` (M) is
  not 2^256 − 1, `snapshot_height_word`, the whole word at T, equals H, the records form a valid set
  (1 to 128 members, valid and distinct keys, no bit of word 2 above `power`, every power at least
  1, their exact sum at most MAX = ⌊(2^63 − 1) / 8⌋) and `snapshot_total_stake` ≥ M. Only `usable` and
  `signers` are normative: the members in seat order at their stored powers when usable, otherwise
  the fallback keys at power 1, each with its secp256k1eth address. `reason` is a diagnostic label
  for the first condition broken, in the order `min_total_stake_max`, `snapshot_height`,
  `no_members`, `stray_bits`, `invalid_key`, `duplicate_key`, `zero_power`, `power_sum` and
  `below_min_total_stake`. Each unusable case breaks one condition, except `zero_prefix`, whose zero
  word 2 is both ckPrefix 0 and power 0. The power sum is exact: `power_sum` sums to MAX + 1 and
  `power_sum_max` to exactly MAX, which is usable, and `power_sum_wraps` has 128 members at 2^57,
  whose sum 2^64 exceeds MAX although a 64-bit sum wraps it to 0. A reader that wraps, or that
  rejects a sum equal to MAX, fails one of them. The member count is pinned at both ends: `full_128`
  is usable with a member in every seat at the reference minStake's power (powers summing to 10^18,
  the whole supply staked), and `one_member` is usable with one member at power 1.
- JSON null appears in two places: `staking_layout.key_seat_words[].seat` is null when the value
  gives the key no seat (null, not 0, since 0 is seat 0), and `candidate.cases[].reason` is null
  exactly when the candidate is usable.
- `on_block_start`: `deployment` holds the staking parameters every case starts from (those of the
  top-level `deployment`) and `overrides` the ones a case changes; m is `min_stake`. Bond i
  registers the key of `private_key` 0x100 + i with `amount` and takes `seat`, the lowest empty
  seat. After the registrations, the `prior_calls` run in order, one block each, before the call in
  block `block_number`; they may take penalties but release no seat. `expect` is the state the call
  leaves: `miss_counts` of the seats held when the call starts (every other seat's count is 0, and
  so is the count of a seat the call releases), every bond's effStake, the bonds whose seats the
  call `released`, the `penalty_total` the call itself sends to `slashSink`, the nonzero `records`
  (all others are zero), `snapshot_total_stake`, `snapshot_height` (the block number) and
  `last_generation`. The cases: a miss count rising to 3 and one reset to 0; a bit of an empty
  seat; a zero bitmap; bitmap 4, which counts only seat 2; bit 100 with n_max 64; with missLimit
  10, the penalty on 10m (m) and on 10m + 1 (m + 1, rounded up), each leaving the count at 10, and
  one miss short of it; a penalty that leaves a bond below m and releases its seat; missLimit 1;
  missSlashBps 10,000, which takes the whole stake; seats 0, 2 and 5 left after three releases in
  the same call; no seat with every bit set; vp_unit = m, where 2.5m gives power 2; n_max 64 with
  every seat held, records 64–127 zero; and, with missLimit 10 and missReleaseLimit 30, the second
  penalty at count 20 on the 9m the first left, a 0 bit after the penalty at 10, which resets the
  count, the release at count 30 after that count's penalty, the release at count 25 with
  missReleaseLimit 25 and no penalty, one penalty and the release at count 10 with both limits 10,
  and 1.2m, which the penalty at count 20 leaves below m, released before the limit.

## Regenerating

Run from the repository root, with Foundry's `cast`, Go and the workspace's dependencies
installed (the output is formatted by running the repository root's `node_modules/.bin/prettier`
directly; generation stops if it is missing):

```bash
python3 -I testdata/etna_vectors/generate.py
```

`generate.py` holds the inputs, the packing table and the storage slot numbers, written from
appendices A and B. Every ABI encoding, hash and storage slot is computed by `cast`, independently
of the contracts and of the node. Every literal of appendix A's vectors must reproduce, or
generation stops. Three Go modules, each in its own directory and never imported by the root
module, are run with `go run` (a `GOFLAGS` in the environment, such as `-p=2`, is kept):

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
validator-state chains and the staking sections) and run in the protocol CI:

```bash
python3 -m unittest discover -s testdata/etna_vectors -p 'test_vectors.py' -v
```

## Consumers

- Contracts (`packages/protocol`; `foundry.toml` grants read access to this directory):
  `test/shared/etna/LibEtnaVectors.sol` loads the file for the Etna Solidity tests, and the key,
  vote and staking tests check their own sections.
- `fallback_keys`, `staking_layout` and `on_block_start` pin what the Inbox and the staking
  contract must do; `miss_bitmap` and `candidate` pin the node's and the guests' own rules.
- The Etna node and guests read the same file. The L1 contracts hold no validator-state hash, so
  `validator_states`, `app_hashes` and `val_state_chains` serve the node.
