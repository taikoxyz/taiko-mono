# Etna vectors

`vectors.json` holds the Etna values that the L1 contracts and the Etna node must agree on byte for
byte. Both sides read this one file instead of carrying their own copies of the literals:

- `committee_config`: the `ETNA_PARENT_ANCHOR_V2` configuration opening that `EtnaInbox` stores as
  `committeeConfigHash` (slot 269): its eleven input words, the 352-byte preimage and the hash.
- `land_statement`: the `TAIKO_ETNA_LAND_V7` landing statement that `EtnaInbox.land` verifies: its
  nineteen inputs (the blob hashes in transaction order; the validator participation, one part per
  epoch with its signed counts and proposer scores), the packed blob hashes hash, the
  participation's ABI encoding and hash, the hash of an empty participation, the 608-byte preimage
  and the statement hash.
- `committee_hashes`: three committees (`CommitteeMember[]`), their ABI encodings and hashes: the
  committee hash a participation part binds and `EtnaRewardPool` checks a settlement list against.
- `registry_entries`: five staking-registry entries, their `ETNA_REG_ENTRY_V2` leaves and the entries
  root of every prefix (0 to 5 entries, zero-padded to the next power of two).
- `layout`: the storage the node proves with EIP-1186 proofs. For the Inbox: the plain slot numbers,
  the bit offsets of every packed field, the anchor and genesis witness slot lists in proof order,
  and the two slots of a forced inclusion queue entry. For the registry: the ERC-7201 base, the
  checkpoint and entry array slots, the packed checkpoint and entry words, and the slots a committee
  witness proves for a snapshot (`snapshot_slots`, with and without the next checkpoint).

All integers are decimal strings, so values above 2^53 survive every JSON parser.

## Regenerating

Run from the repository root, with Foundry's `cast` on `PATH` and the workspace's pnpm dependencies
installed (the output is formatted with the repository's prettier):

```bash
python3 testdata/etna_vectors/generate.py
```

`generate.py` holds the inputs and the storage layout table; every encoding, hash and storage slot
is computed by `cast`, independently of the contracts and of the node. Regeneration is idempotent.

## Consumers

- Contracts (`packages/protocol`, profile `layer1`; `foundry.toml` grants read access to this
  directory): `test/layer1/etna/LibEtnaVectors.sol` loads the file for `EtnaVectors.t.sol` (the
  layout against a deployed Inbox and registry), `EtnaInboxLand.t.sol` (configuration opening and
  V7 statement), `EtnaRewardPool.t.sol` (committee hashes), `LibEntriesTree.t.sol` (leaves and
  roots) and `EtnaStakingRegistry.t.sol` (registry slots).
- Etna node (`packages/taiko-client-rs`, through `include_str!`): the `abci` crate's committee
  tests (configuration hash, leaves and roots, snapshot slots and checkpoint packing), storage
  layout tests, Inbox witness decoding test and fixture planter test, and the `lander` crate's
  V7 statement and committee hash tests.

taiko-client-rs keeps a byte-identical copy of this directory taken from the protocol revision its
lander fixtures pin: `packages/taiko-client-rs/script/gen_lander_artifacts.sh` copies it and
records each file's SHA-256 in the fixture manifest, and a lander unit test checks the copy
against those hashes.
