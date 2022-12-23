---
sidebar_position: 7
---

# 🔍 Explore the network

Taiko's Alpha-1 testnet consists of L1 / L2 nodes with all [Taiko protocol contracts](/docs/category/contract-documentation) deployed.

## Endpoints

### L1

The mining interval of the L1 node is set to 12 seconds.

- **Block Explorer:** <https://l1explorer.a1.taiko.xyz>
- **HTTP RPC Endpoint:** <https://l1rpc.a1.taiko.xyz>
- **Web Socket RPC Endpoint:** <wss://l1ws.a1.taiko.xyz>
- **ETH faucet:** <https://l1faucet.a1.taiko.xyz>
- **Chain ID:** `31336`

### L2

- **Block Explorer:** <https://l2explorer.a1.taiko.xyz>
- **HTTP RPC Endpoint:** <https://l2rpc.a1.taiko.xyz>
- **Web Socket RPC Endpoint:** <wss://l2ws.a1.taiko.xyz>
- **Grafana Dashboard:** <https://grafana.a1.taiko.xyz/d/FPpjH6Hik/geth-overview?orgId=1&refresh=1m&from=now-24h&to=now>
- **Chain ID:** `167003`

## Contract addresses

### L1

- **TaikoL1:** `0x7B3AF414448ba906f02a1CA307C56c4ADFF27ce7`
- **TokenVault:** `0xAE4C9bD0f7AE5398Df05043079596E2BF0079CE9`
- **Bridge:** `0x0237443359aB0b11EcDC41A7aF1C90226a88c70f`

### L2

- **TaikoL2:** `0x0000777700000000000000000000000000000001`
- **TokenVault:** `0x0000777700000000000000000000000000000002`
- **EtherVault:** `0x0000777700000000000000000000000000000003`
- **Bridge:** `0x0000777700000000000000000000000000000004`
- **Pre-deployed ERC-20:** `0x0000777700000000000000000000000000000005`

## Cron job

There will be a cron job service that sends L1 / L2 transactions intervally, so each mined L1 / L2 may include some extra transactions:

### L1 block

- A L1 -> L2 `TokenVault.sendERC20` transaction
- A L1 -> L2 `TokenVault.sendEther` transaction

### L2 block

- A L2 -> L1 `TokenVault.sendERC20` transaction
- A L2 -> L1 `TokenVault.sendEther` transaction
- A pre-deployed ERC-20 token transfer transaction
