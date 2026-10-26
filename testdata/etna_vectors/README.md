# Etna vectors

`vectors.json` holds the values that the Etna L1 contracts, the Etna node and both proving guests
must agree on byte for byte: storage layout, ABI encodings and hashes, signature and key formats,
and the accept/reject cases of every boundary rule. Every implementation reads this one file
instead of carrying its own copies of the literals. Section numbers below refer to the Etna
specification; appendix A is the encodings and appendix B the L1 storage layout.

Schema version is `"4"`. All integers are decimal strings, so values above 2^53 survive every
JSON parser. Hex values are `0x`-prefixed. Clients must decode every input exactly: a decoder
consumes all of its input and rejects trailing bytes, as the reject cases below require.

## Sections

| Section             | Spec           | What it pins                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| ------------------- | -------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `deployment`        | 10, 11         | The deployment every other section uses: L1 chain id 1, L2 chain id 167001, Inbox proxy `0x1111…11`, registry `0x2222…22` and `L2_BLOCK_GAS_LIMIT` 45,000,000.                                                                                                                                                                                                                                                                                                                                                                                                                                |
| `keys`              | 4.1, A         | Six secp256k1 consensus keys (scalars 0xA1–0xA5 and the first scalar whose X has a zero top byte): the 33-byte compressed key, `ckPrefix`, `ckX`, `ckY`, `ckAddr = keccak256(ckX ‖ ckY)[12:]` and the recovery `entryKey = keccak256(abi.encode(ckPrefix, ckX))`.                                                                                                                                                                                                                                                                                                                             |
| `key_decompression` | 4.1, A         | Every key decoded from its own prefix and from the other one (the negated point, a different `ckAddr`), and the inputs registration rejects, each with a `reason`: X ≥ p (X is never reduced mod p), off-curve X, bad prefix, uncompressed (64 or 65 bytes), hybrid, trailing bytes, short, empty, the 66-byte ASCII hex text of a key (`textual`) and the single byte 0x00 (`identity`).                                                                                                                                                                                                     |
| `register_digests`  | 4.1, A         | The EIP-712 `Register(address owner)` domain separator, struct hash and digest at the deployment registry on L1 chain 1, and a proof of possession (65 bytes, V ∈ {0, 1}, low s) by every key for two owners.                                                                                                                                                                                                                                                                                                                                                                                 |
| `pop_rejections`    | 4.1            | PoPs a registration by `owner` rejects although the key decodes: V of 27 or 2, high s, r or s zero, r = n, an r with no curve point, 64 or 66 bytes, and well-formed signatures bound to another owner, key, chain or verifying contract, or submitted with the other-parity key of their signer. `wrong_chain` is signed for chain id 167001 and `wrong_registry` with verifying contract `0x1111…11`.                                                                                                                                                                                       |
| `committee_config`  | 4.3, 6.4, A, B | `committeeConfigHash` (Inbox slot 269): the seven input words (`ETNA_PARENT_ANCHOR_V1`, L2 chain id, registry, `vp_unit`, `s_min`, `n_max`, `U`), the 224-byte preimage and the hash.                                                                                                                                                                                                                                                                                                                                                                                                         |
| `registry_entries`  | 4.1, A         | Five entries from keys a1–a5, their `ETNA_REG_ENTRY_V1` leaves, the leaf of released slot 5 (all-zero fields, still a non-zero leaf) and the entries root of every prefix from 0 to 6 leaves.                                                                                                                                                                                                                                                                                                                                                                                                 |
| `committee_sets`    | 4.3, A         | Committees of 0, 1, 3 and 5 members in ascending set-key order: set keys, `ETNA_SET_LEAF_V1` preimages and leaves with `k = targetEpoch + 1`, `ETNA_SET_NODE` inner nodes with odd-node promotion, total power and the five-field `ETNA_COMMITTEE_V1` record. The empty committee is invalid and has no root or record.                                                                                                                                                                                                                                                                       |
| `cuts`              | 6.1, 6.3, A    | Cut leaves `keccak256(abi.encode(x, blockHash, cometHash, forcedHead))` for heights 0–18 of a fixed model (EL hash 100 + x, Comet hash 200 + x and 0 at x = 0, FI cursor x / 6), and `ETNA_LAND_CUTS_V1` cut hashes over the grid points strictly between p and h, including the empty list (`keccak256("")`) and a 49-leaf case.                                                                                                                                                                                                                                                             |
| `land_statements`   | 6.1, 6.2, A    | The 21-word (672-byte) `TAIKO_ETNA_LAND_V1` statement for a generation-0 landing from block 0 and a generation-1 landing from height 6.                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| `land_abi`          | 6.1            | The `land(input, leaves, proof)` signature, selector and complete calldata of the generation-1 statement.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| `chain_domains`     | 3.1, A         | `chainDomain` and the 48-byte CometBFT chain id `"etna-" + base64url_no_padding(chainDomain)` for generations 0, 1, 2 and 2^48 − 1 and for another Inbox.                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| `votes`             | 4.1, A         | CometBFT vote sign bytes and secp256k1eth signatures by key a1: round 0 omitted, nil and partial block ids, a hash with an empty part set header (`12 00`), a zero timestamp (`2a 00`), the largest signable values and one- and two-byte length prefixes. `pairs` are double-sign evidence with the verdict at a given current generation: conflicts (including one from a historical generation) and non-slashable pairs that differ in type, height, round or generation (each also with conflicting block ids), share a block id, or come from a future generation or another deployment. |
| `fi_eligibility`    | 7.2            | Raw forced-inclusion transactions at the deployment's L2 chain id and block gas limit, each `eligible` or not. See the notes below.                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| `extra_data`        | 3.2, A         | The 13-byte `extraData = 0x64 ‖ uint48_be(generation) ‖ uint48_be(anchorNumber)`.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| `packed_words`      | B              | Every packed storage word (Inbox slots 272, 281, 282, the second word of a slot-280 entry and the first word of a slot-285 record; the registry's first checkpoint word and third entry word) with an ordinary and an all-max item.                                                                                                                                                                                                                                                                                                                                                           |
| `origin_words`      | 8.4, B         | Slot-290 origins `(startHeight, l1BlockNumber, l1Timestamp)`, three full words each. The items are encoding-only: the all-max item's `start_height` is not a grid point.                                                                                                                                                                                                                                                                                                                                                                                                                      |
| `layout`            | A, B           | For the Inbox: the named slots, the reserved slots, the packing table, the initialized status (3), the anchor witness slots in proof order (268, 270, 271, 281) and the mapping slots of forced inclusion entries, landings and origins. For the registry: the ERC-7201 base R of `taiko.etna.registry`, the checkpoint (R) and entry (R + 1) array slots, the packing table, the slots a committee witness proves for a snapshot, and the `owners` and `exit_confirmations` namespaces.                                                                                                      |

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

## Regenerating

Run from the repository root, with Foundry's `cast`, Go and the workspace's pnpm dependencies
installed (the output is formatted with the repository's prettier):

```bash
python3 testdata/etna_vectors/generate.py
```

`generate.py` holds the inputs, the packing table and the storage slot numbers, written from
appendices A and B. Every ABI encoding, hash and storage slot is computed by `cast`, independently
of the contracts and of the node. Two Go modules, each in its own directory and never imported by
the root module, are run with `go run`:

- `votegen/` signs every vote with stock CometBFT v0.40.0 (`types.VoteSignBytes` and the
  secp256k1eth key type). Generation stops if any sign-byte string differs from a separate Python
  encoder written from appendix A; neither side is adjusted to match the other.
- `ficheck/` checks the written `fi_eligibility` cases against go-ethereum v1.15.5.

Regeneration is deterministic: two runs produce identical bytes. The structural tests need only
the Python standard library and run in the protocol CI:

```bash
python3 -m unittest discover -s testdata/etna_vectors -p 'test_vectors.py' -v
```

## Consumers

- Contracts (`packages/protocol`, profile `layer1`; `foundry.toml` grants read access to this
  directory): `test/layer1/etna/LibEtnaVectors.sol` loads the file for `EtnaVectors.t.sol`, which
  checks the Inbox and registry layout through their views and rebuilds every appendix A encoding,
  and for `LibEntriesTree.t.sol`, which checks the entry leaves and roots.
- Etna node and guests (`packages/taiko-client-rs`): `script/gen_lander_artifacts.sh` copies the
  top-level files of this directory, byte for byte, to the same path in the client and records
  each file's SHA-256 in the fixture manifest; `script/check_lander_artifacts.sh` checks the copy
  against the pinned protocol revision. The `votegen/` and `ficheck/` subdirectories are not
  copied.
