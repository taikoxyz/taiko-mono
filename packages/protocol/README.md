# Taiko Protocol

This repository contains the Taiko Based Contestable Rollup (BCR) protocol and supporting tools. The project is managed using `pnpm` and `foundry`.

## Prerequisites

Before compiling the smart contracts, ensure the following are installed and up to date:

- [Foundry](https://book.getfoundry.sh/)
- [pnpm](https://pnpm.io/)

To install dependencies:

```bash
foundryup && pnpm install
```

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

Tests can be described using yaml files. They will be automatically transformed into solidity test files with [bulloak](https://github.com/alexfertel/bulloak).

Create a file with `.t.yaml` extension within the `test` folder and describe a hierarchy of test cases:

```yaml
# MyTest.t.yaml

MultisigTest:
  - given: proposal exists
    comment: Comment here
    and:
      - given: proposal is in the last stage
        and:
          - when: proposal can advance
            then:
              - it: Should return true

          - when: proposal cannot advance
            then:
              - it: Should return false

      - when: proposal is not in the last stage
        then:
          - it: should do A
            comment: This is an important remark
          - it: should do B
          - it: should do C

  - when: proposal doesn't exist
    comment: Testing edge cases here
    then:
      - it: should revert
```

Then use `make` to automatically sync the described branches into solidity test files.

```sh
$ make
Available targets:
Available targets:
- make all        Builds all tree files and updates the test tree markdown
- make sync       Scaffold or sync tree files into solidity tests
- make check      Checks if solidity files are out of sync
- make markdown   Generates a markdown file with the test definitions rendered as a tree
- make init       Check the dependencies and prompt to install if needed
- make clean      Clean the intermediary tree files

$ make sync
```

The final output will look like a human readable tree:

```
# MyTest.tree

EmergencyMultisigTest
├── Given proposal exists // Comment here
│   ├── Given proposal is in the last stage
│   │   ├── When proposal can advance
│   │   │   └── It Should return true
│   │   └── When proposal cannot advance
│   │       └── It Should return false
│   └── When proposal is not in the last stage
│       ├── It should do A // Careful here
│       ├── It should do B
│       └── It should do C
└── When proposal doesn't exist // Testing edge cases here
    └── It should revert
```

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
