# Use the bridge

These steps will help you to use the bridge to transfer assets between Ethereum A1 and Taiko A1. All the bridge contracts can be found [here](/docs/reference/contract-addresses).

## Prerequisites

- Have some ETH or HORSE on either Ethereum A1 or Taiko A1. If you don't have any, you can [request from faucet](/docs/testnet-guide/request-from-faucet).

## Steps

1. Visit the [bridge](https://bridge.a1.taiko.xyz/) and follow through the UI to bridge your tokens.

## Common problems

### Why is my L2 -> L1 transfer taking so long?

The transfer from L2 to L1 can take a while because Taiko has a several hours delay in syncing block headers to allow uncle proof generation time, and we need the synced header to match so the Merkle proof of the message being sent on L2 is valid on L1.
