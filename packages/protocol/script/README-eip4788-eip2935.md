# Deploying EIP-4788 and EIP-2935 on Taiko L2

`deploy_eip4788_eip2935.sh` installs the two Ethereum system contracts at their
canonical, chain-independent addresses on Taiko L2:

| EIP                          | Address                                      | Runtime size |
| ---------------------------- | -------------------------------------------- | ------------ |
| EIP-4788 (beacon roots)      | `0x000F3df6D732807Ef1319fB7B8bB8522d0Beac02` | 97 bytes     |
| EIP-2935 (historical hashes) | `0x0000F90827F1C53a10cb7A02335B175320002935` | 83 bytes     |

## Why `PRIVATE_KEY` does not deploy these

Neither address can be reached with an ordinary deployment. Each one is
`CREATE(deployer, nonce = 0)` for a one-time "keyless" EOA whose private key
nobody holds:

| EIP      | Keyless deployer                             |
| -------- | -------------------------------------------- |
| EIP-4788 | `0x0B799C86a49DEeb90402691F1041aa3AF2d3C875` |
| EIP-2935 | `0x3462413Af4609098e1E27A490f554f260213D685` |

The only way to put code there is to rebroadcast the pre-signed, pre-EIP-155
deployment transaction published in each EIP. `PRIVATE_KEY` is used solely to
**fund** those deployers so their own transaction can pay for its gas.

Both Taiko RPCs accept pre-EIP-155 (unprotected) transactions, which is what
makes this possible. If you point the script at an endpoint that rejects them,
`cast publish` fails and the script says so.

## Cost

The signature covers `gas = 250,000` and `gasPrice = 1000 gwei`, so the funding
amount is fixed at **0.25 ETH per contract** and cannot be lowered. The
deployment burns only what it uses; the remainder stays in the keyless EOA
permanently, because nobody can sign a transaction to move it.

| Per chain      | Amount        |
| -------------- | ------------- |
| Funding to send| 0.50 ETH      |
| Burned as gas  | ~0.147 ETH    |
| Stranded forever | ~0.353 ETH  |

The script prints the exact split, computed from a live `eth_estimateGas`,
before it sends anything.

## Usage

```bash
cd packages/protocol

# Read-only. Prints current state and the exact cost. Sends nothing.
./script/deploy_eip4788_eip2935.sh --network all

# Testnet first.
PRIVATE_KEY=0x... ./script/deploy_eip4788_eip2935.sh --network hoodi --broadcast

# Mainnet. Prompts for a typed confirmation unless --yes is passed.
PRIVATE_KEY=0x... ETHERSCAN_API_KEY=... \
  ./script/deploy_eip4788_eip2935.sh --network mainnet --broadcast

# After deploying: is the client actually feeding the contracts?
./script/deploy_eip4788_eip2935.sh --network all --check
```

Networks: `mainnet` (167000), `hoodi` (167013), or `all`. Re-running after a
successful deployment is a no-op — contracts already carrying the canonical
bytecode are reported and skipped.

## Verification

These two contracts are hand-written EVM assembly with no Solidity or Vyper
source, so Etherscan **source** verification is not possible for them (they are
unverified on Etherscan mainnet for the same reason). The script verifies them
the only way that actually proves anything:

1. After publishing, it reads the code back over RPC and asserts it is
   byte-identical to the canonical runtime bytecode.
2. If `ETHERSCAN_API_KEY` (V2) is set, it re-reads the code through Etherscan's
   own node as an independent cross-check. Both Taiko chains are covered by the
   Etherscan V2 multichain API (`taikoscan.io`, `hoodi.taikoscan.io`).

The pre-signed transactions embedded in the script were checked against
Ethereum mainnet — signer, transaction hash and installed runtime bytecode all
match what L1 carries:

| EIP      | Deployment tx hash on L1                                             |
| -------- | -------------------------------------------------------------------- |
| EIP-4788 | `0xdf52c2d3bbe38820fff7b5eaab3db1b91f8e1412b56497d88388fb5d4ea1fde0` |
| EIP-2935 | `0x67139a552b0d3fffc30c0fa7d0c20d42144138c8fe07fc5691f09c1cce632e15` |

## Deploying the code is not the whole story

Both EIPs work by having the execution client make a system call into the
contract at the start of every block. Deploying the bytecode does not by itself
make either contract useful — run `--check` afterwards to see what is really
happening:

- **EIP-2935** — Taiko L2 headers carry `requestsHash` and `withdrawalsRoot`,
  so the chain is past Prague and the client should begin writing block hashes
  into the ring buffer once the contract has code. Per the EIP the system call
  is a no-op while the address is empty, so the buffer starts empty and fills
  over the following 8191 blocks. `--check` probes the freshest slot
  (`head - 1`), so give it a block after deploying before trusting an empty
  result.

- **EIP-4788** — `parentBeaconBlockRoot` is currently **zero** in Taiko L2
  headers on both mainnet and Hoodi. The contract can only ever store what the
  header carries, so it will return zero for every timestamp until Taiko starts
  populating that field. Deploying it still puts the canonical bytecode at the
  canonical address for L1 equivalence and for contracts that probe whether the
  address has code, but it will not yield real beacon roots on its own.
