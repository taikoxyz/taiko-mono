# Taiko Protocol

This repository contains the Taiko Based Contestable Rollup (BCR) protocol and supporting tools. The project is managed using `pnpm` and `foundry`.

## Prerequisites

Before compiling the smart contracts, ensure the following are installed and up to date:

- [Foundry](https://book.getfoundry.sh/)
- [pnpm](https://pnpm.io/)

To install dependencies:

```bash
pnpm install
```

Foundryup will automatically update during the post-installation script to the version specified in `.tool-versions`.

## Compilation

Taiko’s protocol is split between Layer 1 (L1) and Layer 2 (L2). The smart contracts need to be compiled and tested separately for each layer:

To compile and generate the storage layout for L1:

```bash
pnpm compile:l1
pnpm layout:l1
```

Similarly, for L2:

```bash
pnpm compile:l2
pnpm layout:l2
```

To compile and generate the storage layout for both layers:

```bash
pnpm compile
pnpm layout
```

## Testing

```bash
pnpm test:l1
pnpm test:l2
pnpm test
```

## Etna L1 state-root proofs

The state-root design in [#22237](https://github.com/taikoxyz/taiko-mono/pull/22237) puts the L1
anchor execution state root in `parentBeaconBlockRoot` and the anchor number in the L2 header's
13-byte `extraData`. `Anchor.getL1StateRoot(l2Timestamp)` reads the root recorded by the canonical
EIP-4788 contract. It rejects pre-Etna timestamps, zero roots and unavailable entries.

L2 uses `SignalServiceL2`, with the existing Anchor as both its checkpoint writer and state-root
provider. Bridge continues to pass opaque proof bytes to the same SignalService proxy. Encode an
Etna proof as:

```solidity
abi.encodePacked(
    bytes4(keccak256("TAIKO_STATE_ROOT_PROOF_V1")),
    abi.encode(ISignalServiceL2.StateRootProof({
        l2Timestamp: l2Timestamp,
        accountProof: accountProof,
        storageProof: storageProof
    }))
)
```

The timestamp is an L2 timestamp. The verifier obtains the root from Anchor and verifies the remote
SignalService's account and signal slot. It accepts no caller-supplied L1 block number, block hash
or state root. A successful `proveSignalReceived` caches the signal and returns the existing cache
operation count `0`; `verifySignalReceived` only reads state. Legacy `HopProof[]` and empty cached
proofs retain their encoding. L1 continues to use `SignalService`.

EIP-4788 entries can be overwritten by a later timestamp with the same remainder modulo 8191.
When a proof's entry is unavailable, select a recent settled L2 timestamp and regenerate the L1
Merkle proof against the corresponding anchor state root. Once a signal has been cached, an empty
proof remains valid after oracle expiry. There is no separate reveal transaction or new
`CheckpointSaved` event in this path. Relayer and bridge UI consumers must select the anchor from
the L2 header, construct this envelope and refresh expired proofs; the checkpoint-reveal flow in
[#22228](https://github.com/taikoxyz/taiko-mono/pull/22228) must be adapted before activation.

### Existing SignalService storage

`SignalServiceL2` adds no storage slots. Its immutable `usesLegacyStorage` selects exactly one
layout for checkpoint and received-signal cache reads **and writes**:

- `true`: the unversioned flat mappings used by the pre-VERSION Shasta implementation.
- `false`: the current `SignalService.VERSION` namespace. Deprecated unversioned records remain
  inaccessible, as they do in the current implementation.

There is no fallback between layouts. Verify the existing proxy implementation and storage layout
before choosing the flag; changing it on a later upgrade changes which records are accessible.
`VERSION()` describes the inherited versioned namespace, while `usesLegacyStorage()` determines
whether that namespace is used. The existing L2 deploy scripts require both `ETNA_TIMESTAMP` and
`SIGNAL_SERVICE_USES_LEGACY_STORAGE` explicitly. They read and preserve the existing proxy's
pauser; a missing getter is accepted only for an explicitly selected legacy layout, whose older
implementation had no additional pause authority. Their deployments do not upgrade either proxy.
Upgrade the existing SignalService proxy to the matching-layout Etna implementation, and install
the Anchor timestamp gate strictly before the first anchorless block. Preserve the remote
SignalService, owner, pauser and proxy addresses. New genesis allocations use versioned storage
(`usesLegacyStorage = false`). Execution clients, drivers and prover guests must implement the
matching root and 13-byte header rules before Etna activates.

## Layer 2 Genesis Block

### Generating a Dummy Genesis Block

To generate dummy data for the L2 genesis block, create a configuration file at `./test/genesis/data/genesis_config.js` with the following content:

```javascript
module.exports = {
  contractOwner: "0xDf08F82De32B8d460adbE8D72043E3a7e25A3B39",
  chainId: 167,
  seedAccounts: [
    { "0xDf08F82De32B8d460adbE8D72043E3a7e25A3B39": 1024 },
    { "0x79fcdef22feed20eddacbb2587640e45491b757f": 1024 },
  ],
  l1ChainId: 31337,
  etnaTimestamp: "0xffffffffffffffff", // never; "0x0" = Etna from genesis
  ownerSecurityCouncil: "0xDf08F82De32B8d460adbE8D72043E3a7e25A3B39",
  ownerTimelockController: "0xDf08F82De32B8d460adbE8D72043E3a7e25A3B39",
  param1559: {
    gasExcess: 1,
  },
  predeployERC20: true,
};
```

Then compile the L2 contracts and generate the genesis block:

```bash
pnpm compile:l2
pnpm genesis:gen
```

This generates the following JSON files in `./test/genesis/data/`:

- `l2_genesis_alloc.json`: Contains the `alloc` field for the L2 genesis block. Use this in a `geth` or `taiko-geth` genesis block following [this guide](https://geth.ethereum.org/docs/fundamentals/private-network#creating-genesis-block).
- `l2_genesis_storage_layout.json`: Displays the storage layout of the pre-deployed contracts.

To validate the genesis data:

```bash
pnpm genesis:test
```

This runs tests using Docker and `taiko-geth` to simulate the L2 genesis block deployment, and generates a `genesis.json` file in `./test/genesis/data/`.

### Generating an Actual Genesis Block

To generate the actual L2 genesis block, create a `genesis.json` file based on `l2_genesis_alloc.json`, following [this guide](https://geth.ethereum.org/docs/fundamentals/private-network#creating-genesis-block).

Next, initialize `taiko-geth` with the generated `genesis.json`:

```bash
geth --datadir ~/taiko-l2-network/node init test/layer2/genesis/data/genesis.json
geth --datadir ~/taiko-l2-network/node --networkid 167 --http --http.addr 127.0.0.1 --http.port 8552 --http.corsdomain "*"
```

You can retrieve the genesis block hash by attaching to the `geth` instance:

```bash
geth attach ~/taiko-l2-network/node/geth.ipc
```

Then run:

```bash
eth.getBlock(0)
```

Copy the genesis block hash and replace the `L2_GENESIS_HASH` variable in `deploy_protocol_on_l1.sh` with this value.

### Deploying Taiko BCR on Layer 1

To deploy Taiko BCR on L1, start a local L1 network:

```bash
anvil --hardfork cancun
```

Make sure you have sufficient ether for transactions, then deploy the contracts:

```bash
pnpm test:deploy:l1
```

This command runs the deployment script located at `script/deploy_protocol_on_l1.sh`, assuming L1 is accessible at `http://localhost:8545`.

## Style Guide

Refer to [CONTRIBUTING.md](../../CONTRIBUTING.md) for code style guidelines.

Before committing code, format and lint it using:

```bash
pnpm fmt:sol
```
