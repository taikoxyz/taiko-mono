# How Taiko is deployed

The Taiko protocol smart contracts are deployed on L1 and L2. The L2 contracts are pre-deployed first by creating a genesis block, and then the L1 contracts are deployed using a script. The general flow is like this:

1. A `genesis.json` is generated, which includes the L2 contracts (see: [generate genesis](../utils/generate_genesis/generate.ts)).
2. The `genesis.json` is used as input to generate the genesis block (see: https://geth.ethereum.org/docs/fundamentals/private-network#creating-genesis-block).
3. The L1 smart contracts are deployed by executing the L1 deployment script, [DeployProtocolOnL1.s.sol](../script/layer1/DeployProtocolOnL1.s.sol). The L1 deployment script takes in artifacts from the L2 deployment such as the deployed contract addresses, and genesis block hash.
