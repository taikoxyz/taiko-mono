# Taiko Protocol

This package contains Taiko Based Contestable Rrollup protocol and assisting code managed by pnpm and foundry.

## Getting Started

Before compiling smart contracts, ensure all necessary dependencies are installed and foundry is installed and up to date.

```sh
foundryup && pnpm install
```

As solidity code are partially compiled for layer 1 (aka Ethereum) and partially compiled for layer 2 (aka Taiko), you need to compile the code for both layer1 and layer2.

To compile, test, and generate contract storage layout tables for layer 1:

```sh
pnpm compile:l1
pnpm test:l1
pnpm layout:l1
```

You can do the same for layer2:

```sh
pnpm compile:l2
pnpm test:l2
pnpm layout:l2
```

To compile and test for both layer 1 and layer 2:

```sh
pnpm compile
pnpm test
pnpm layout
```

## Layer 2 Genesis Block

### Generating a dummy genesis block

First, you need to create a `config.js` file in this directory with the following content:

```javascript
module.exports = {
  // Owner address of the pre-deployed L2 contracts.
  contractOwner: "0xDf08F82De32B8d460adbE8D72043E3a7e25A3B39",
  // Chain ID of the Taiko L2 network.
  chainId: 167,
  // Account address and pre-mint ETH amount as key-value pairs.
  seedAccounts: [
    { "0xDf08F82De32B8d460adbE8D72043E3a7e25A3B39": 1024 },
    { "0x79fcdef22feed20eddacbb2587640e45491b757f": 1024 },
  ],
  // Owner Chain ID, Security Council, and Timelock Controller
  l1ChainId: 31337,
  ownerSecurityCouncil: "0xDf08F82De32B8d460adbE8D72043E3a7e25A3B39",
  ownerTimelockController: "0xDf08F82De32B8d460adbE8D72043E3a7e25A3B39",
  // L2 EIP-1559 baseFee calculation related fields.
  param1559: {
    gasExcess: 1,
  },
  // Option to pre-deploy an ERC-20 token.
  predeployERC20: true,
};
```

Then, compile the layer 2 contracts and execute a script:

```sh
pnpm compile:l2 && pnpm genesis:gen config.js
```

The script will output two JSON files under `./test/genesis/data/`:

- `l2_genesis_alloc.json`: the `alloc` field which will be used in L2 genesis JSON file
- `l2_genesis_storage_layout.json`: the storage layout of those pre-deployed contracts

You can output the dummy genesis block by running the following command:

```sh
pnpm genesis:test
```

This test, defined in `./test/genesis/genesis.test.sh`, compiles the contracts, generates the genesis JSON, and initiates a Geth node using Docker to simulate the deployment of the genesis block. Reviewing this script and its output can help you grasp the steps required to create and initiate a genesis block for the Taiko Protocol.

If this process is unclear to you, please reach out to us on [Discord](https://discord.gg/taiko) or [GitHub](https://github.com/taikoxyz/taiko-mono/issues).

### Generating Actual Genesis Block

After understanding the process from the test, proceed to generate the actual `genesis.json` and the genesis block:

1. **Build the Genesis JSON:** Use the information learned from the `genesis:test` to build the `genesis.json` file from data files in `./test/genesis/data/` directory. The `./test/genesis/genesis.test.sh` script contains the necessary commands to create this file.

2. **Run Geth to Generate the Genesis Block:** You can use Geth to initialize and run a private network with the genesis block. You can start Geth with the following commands:

   ```sh
   geth --datadir ~/taiko-l2-network/node init test/layer2/genesis/data/genesis.json
   geth --datadir ~/taiko-l2-network/node --networkid 167 --http --http.addr 127.0.0.1 --http.port 8552 --http.corsdomain "*"
   ```

   For details refer to the Geth documentation on [creating a genesis block](https://geth.ethereum.org/docs/fundamentals/private-network#creating-genesis-block).

3. **Retrieve the Genesis Block Hash:** Connect to the Geth node using the command:

   ```sh
   geth attach ~/taiko-l2-network/node/geth.ipc
   ```

   In the Geth console, use `eth.getBlock(0)` to obtain the hash of the genesis block.

4. **Update `deploy_protocol_on_l1.sh` File:** Update the `L2_GENESIS_HASH` variable in the `deploy_protocol_on_l1.sh` script with the obtained genesis block hash.

By following these steps, you will successfully generate the L2 genesis block for the Taiko Protocol, retrieve its hash, and prepare for the L1 contract deployment.

## Deploying Contracts on Layer 1

To deploy Taiko Protocol on layer 1, you can use any Ethereum network. The deployment relies on `script/deploy_protocol_on_l1.sh`, which targets a node at `http://localhost:8545` by default.

Here’s how you can proceed:

1. **Secure Sufficient ETH:** Check that the address associated with the private key in `./script/layer1/deploy_protocol_on_l1.sh` has enough ETH for deploying contracts on the layer 1 network.

2. **Update Contract Addresses:** After running the genesis block generation script (`pnpm genesis:test`), you will receive a list of pre-computed contract addresses. These addresses need to be added to the `deploy_protocol_on_l1.sh` file. Make sure to update this file with the correct contract addresses before proceeding with the deployment.

3. **Start a Local Network:** Here we use anvil as an example:

```sh
anvil --hardfork cancun
```

4. **Deploy Contracts Using Foundry:** Once your network is running, open a new terminal window and execute the deployment scripts using Foundry:

```sh
pnpm test:deploy:l1
```

This command will deploy the based protocol contracts using the settings and addresses you’ve provided in the `deploy_protocol_on_l1.sh` script.

## Style Guide

Please see [CONTRIBUTING.md](../../CONTRIBUTING.md) for the source code style guidelines to adhere to.

You need to format and lint your code before committing:

```sh
pnpm fmt:sol
```
