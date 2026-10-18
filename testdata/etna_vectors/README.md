# Etna vectors

`vectors.json` holds the Etna values that the L1 contracts and the Etna node must agree on byte for
byte. Both sides read this one file instead of carrying their own copies of the literals:

- `committee_config`: the `ETNA_PARENT_ANCHOR_V3` configuration opening that `EtnaInbox` stores as
  `committeeConfigHash` (slot 269): its eleven input words, the 352-byte preimage and the hash.
- `land_statement`: the `TAIKO_ETNA_LAND_V9` twenty-one-word (672-byte) landing statement,
  including ordered blob hashes, distinct L1 fee and L2 reward recipients, the base-fee amount, and the terminal active committee snapshot.
- `reward_receipt`: independent cast preimages and hashes for the batch ID, receipt commitment,
  and slot-283 mapping storage location. Chain identity and the parent come from the landing vector.
- `land_selector`: the exact nonpayable two-argument V9 ABI selector.
- `claim_selector`: the exact immutable vault claim ABI selector.
- `zero_fee`: a complete twenty-one-word V9 statement and receipt for the same batch identity with
  amount zero; the receipt is still nonzero and consumable exactly once.
- `committee_sets`: empty (invalid committee), singleton, three- and five-member set-key-ordered
  cases. Each pins recipient-bound `ETNA_SET_LEAF_V2` preimages/leaves, odd-node promotion,
  totals, and the nine-word `ETNA_COMMITTEE_V2` record at encoding version 2. Record
  `target_epoch` is 7; leaves/nodes use explicit `set_version = target_epoch - E0 + 1 = 8`
  with `E0 = 0`. Set version must not be replaced by the record target epoch.
- `registry_entries`: five staking-registry entries, their `ETNA_REG_ENTRY_V2` leaves and the entries
  root of every prefix (0 to 5 entries, zero-padded to the next power of two).
- `layout`: the storage the node proves with EIP-1186 proofs. For the Inbox: the plain slot numbers,
  the bit offsets of every packed field, the anchor and genesis witness slot lists in proof order,
  slot 283 for reward receipts, slot 284 for the active committee snapshot, and the two slots of a forced inclusion queue entry. For the registry: the ERC-7201 base, the
  checkpoint and entry array slots, the packed checkpoint and entry words, and the slots a committee
  witness proves for a snapshot (`snapshot_slots`, with and without the next checkpoint).

Schema version is "3". Obsolete V7 participation and committee-hash vectors are removed.
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
  layout against a deployed Inbox and registry, selectors, zero fees and V2 set/record encodings), `EtnaInboxLand.t.sol` (configuration opening and
  V9 statement, reward receipt and selector), `LibEntriesTree.t.sol` (leaves and roots) and `EtnaStakingRegistry.t.sol` (registry slots).
- Etna node (`packages/taiko-client-rs`, through `include_str!`): the `abci` crate's committee
  tests (configuration hash, leaves and roots, snapshot slots and checkpoint packing), storage
  layout tests, Inbox witness decoding test and fixture planter test, and the `lander` crate's
  V9 statement, receipt and committee set/record tests.

taiko-client-rs keeps a byte-identical copy of this directory taken from the protocol revision its
lander fixtures pin: `packages/taiko-client-rs/script/gen_lander_artifacts.sh` copies it and
records each file's SHA-256 in the fixture manifest, and a lander unit test checks the copy
against those hashes.

## Aligned artifact index

The consuming client records the exact immutable protocol commit in its generator, Rust
`PROTOCOL_REVISION`, fixture manifest and operator documentation. Protocol does not consume
a client revision; the companion client is [PR #22280](https://github.com/taikoxyz/taiko-mono/pull/22280),
and the protocol is [PR #22286](https://github.com/taikoxyz/taiko-mono/pull/22286). Regenerate
this directory, protocol deployment fixtures and the custom-genesis inputs twice and compare bytes.
The client fixture manifest indexes ABI/bytecode and these vectors; the test-harness manifests
separately index fixture Solidity and canonical EL genesis/system runtimes. Runtime genesis
identity also includes the predicted Inbox and L1 chain id, so those inputs must be held fixed.
