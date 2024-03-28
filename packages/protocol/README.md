# Taiko Protocol

This package contains rollup contracts on both L1 and L2, along with other assisting code. Taiko L2's chain ID is [167](https://github.com/ethereum-lists/chains/pull/1611).

## Getting Started

Before compiling smart contracts, ensure all necessary dependencies are installed:

```sh
pnpm install
```

Then, compile the smart contracts:

```sh
pnpm compile
```

If you run into `Error: Unknown version provided`, you should upgrade your foundry installation by running `curl -L https://foundry.paradigm.xyz | bash`.

## Style Guide

Please see [CONTRIBUTING.md](../../CONTRIBUTING.md) for the source code style guidelines to adhere to.

## Generate L2 Genesis JSON's `alloc` Field

Create a `config.js` with the following structure:

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

Then, execute the generation script:

```sh
pnpm compile && pnpm generate:genesis config.js
```

The script will output two JSON files under `./deployments`:

- `l2_genesis_alloc.json`: the `alloc` field which will be used in L2 genesis JSON file
- `l2_genesis_storage_layout.json`: the storage layout of those pre-deployed contracts

## Using Foundry

This project also integrates with Foundry for building and testing contracts.

- To compile using foundry: `forge build` or `pnpm compile`
- To run foundry tests: `forge test --gas-report -vvv` or `pnpm test:foundry`

## Generating and Running the L2 Genesis Block

The generation of the L2 genesis block and obtaining its hash involves a series of steps, including constructing the genesis JSON, followed by the actual generation and retrieval of the genesis block hash. A test can be executed to comprehend this process.

### Testing Genesis Block Creation

To understand how the `genesis.json` is built from deployment files and how to generate the genesis block and its hash, you can use the `test:genesis` command. This test serves as a learning tool:

```sh
pnpm test:genesis
```

This test, defined in `./genesis/generate_genesis.test.sh`, compiles the contracts, generates the genesis JSON, and initiates a Geth node using Docker to simulate the deployment of the genesis block. Reviewing this script and its output can help you grasp the steps required to create and initiate a genesis block for the Taiko Protocol.

### Generating the Actual Genesis Block

After understanding the process from the test, proceed to generate the actual `genesis.json` and the genesis block:

1. **Build the Genesis JSON:** Use the information learned from the `test:genesis` to build the `genesis.json` file from the files in the `/deployments/` directory. The `generate_genesis.test.sh` script contains the necessary commands to create this file.

2. **Run Geth to Generate the Genesis Block:** You can use Geth to initialize and run a private network with the genesis block. You can start Geth with the following commands:

   ```sh
   geth --datadir ~/taiko-l2-network/node init /deployments/genesis.json
   geth --datadir ~/taiko-l2-network/node --networkid 167 --http --http.addr 127.0.0.1 --http.port 8552 --http.corsdomain "*"
   ```

   For details refer to the Geth documentation on [creating a genesis block](https://geth.ethereum.org/docs/fundamentals/private-network#creating-genesis-block).

3. **Retrieve the Genesis Block Hash:** Connect to the Geth node using the command:

   ```sh
   geth attach ~/taiko-l2-network/node/geth.ipc
   ```

   In the Geth console, use `eth.getBlock(0)` to obtain the hash of the genesis block.

4. **Update `test_deploy_on_l1.sh` File:** Update the `L2_GENESIS_HASH` variable in the `test_deploy_on_l1.sh` script with the obtained genesis block hash.

By following these steps, you will successfully generate the L2 genesis block for the Taiko Protocol, retrieve its hash, and prepare for the L1 contract deployment.

## Deploying the L1 Contracts

To deploy L1 contracts for Taiko Protocol, you can use any Ethereum network. This guide illustrates the process using a Hardhat local network, but it's adaptable to others. The deployment relies on `script/test_deploy_on_l1.sh`, which targets a node at `http://localhost:8545` by default.

Here’s how you can proceed:

1. **Ensure Sufficient ETH:** Check that the address associated with the private key in `script/test_deploy_on_l1.sh` has enough ETH for deploying contracts on the Hardhat network.

2. **Update Contract Addresses:** After running the genesis block generation script (`pnpm test:genesis`), you will receive a list of pre-computed contract addresses. These addresses need to be added to the `test_deploy_on_l1.sh` file. Make sure to update this file with the correct contract addresses before proceeding with the deployment.

3. **Start a Local Development Network:** While this guide uses Hardhat as an example, you can use any Ethereum network. If you choose to use Hardhat, start a local Ethereum network for development and testing:

```sh
pnpm hardhat node
```

4. **Deploy Contracts Using Foundry:** Once your network is running, open a new terminal window and execute the deployment scripts using Foundry:

```sh
pnpm test:deploy
```

This command will deploy the L1 contracts using the settings and addresses you’ve provided in the `test_deploy_on_l1.sh` script.

## Running slither

1. Install the latest [slither](https://github.com/crytic/slither?tab=readme-ov-file#how-to-install).
2. From `protocol/`, execute `slither . --checklist > checklist.md` to re-generate the checklist.
