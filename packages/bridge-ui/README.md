# Bridge UI

🚨 **Important** 🚨: Currently the Bridge UI is in maintenance mode. Please, hold off sending PRs.

## Installation

`pnpm install`

## Usage

`pnpm start`

## Environment Variables

You can use the following values in the `.env` file to spin up the Bridge UI locally.

```
VITE_NODE_ENV=dev
VITE_L1_RPC_URL=https://l1rpc.internal.taiko.xyz
VITE_L2_RPC_URL="https://l2rpc.internal.taiko.xyz"

VITE_L1_EXPLORER_URL="https://l1explorer.internal.taiko.xyz"
VITE_L2_EXPLORER_URL="https://l2explorer.internal.taiko.xyz"

VITE_RELAYER_URL="https://relayer.internal.taiko.xyz/"

VITE_L1_CHAIN_ID=31336
VITE_L2_CHAIN_ID=167001

VITE_L1_CHAIN_NAME="Ethereum A3"
VITE_L2_CHAIN_NAME="Taiko A3"

VITE_L1_TOKEN_VAULT_ADDRESS="0xa85233C63b9Ee964Add6F2cffe00Fd84eb32338f"
VITE_L2_TOKEN_VAULT_ADDRESS="0x0000777700000000000000000000000000000002"

VITE_L1_CROSS_CHAIN_SYNC_ADDRESS="0x9A9f2CCfdE556A7E9Ff0848998Aa4a0CFD8863AE"
VITE_L2_CROSS_CHAIN_SYNC_ADDRESS="0x0000777700000000000000000000000000000001"

VITE_L1_BRIDGE_ADDRESS="0x59b670e9fA9D0A427751Af201D676719a970857b"
VITE_L2_BRIDGE_ADDRESS="0x0000777700000000000000000000000000000004"

VITE_L1_SIGNAL_SERVICE_ADDRESS="0x09635F643e140090A9A8Dcd712eD6285858ceBef"
VITE_L2_SIGNAL_SERVICE_ADDRESS="0x0000777700000000000000000000000000000007"

VITE_TEST_ERC20=[{"address": "0x959922bE3CAee4b8Cd9a407cc3ac1C251C2007B1", "symbol": "BLL", "name": "Bull Token"}, {"address": "0x0B306BF915C4d645ff596e518fAf3F9669b97016", "symbol": "HORSE", "name": "Horse Token"}]
```
