# PROPOSAL-0006: Taiko Shasta Fork Upgrade

Upgrade Taiko L1/L2 smart contracts for the Shasta fork: L1 `signal_service` and `preconf_whitelist` proxies, plus L2 `signal_service` and `anchor` proxies. Implementation addresses come from the Shasta deploy scripts (run separately). The new deployed Shasta Inbox will remain owned by `admin.taiko.eth` after execution, a follow-up proposal will be created to accept its ownership after the Shasta genesis proposal initialization.

## Deployment Scripts

- L1 implementations: `script/layer1/mainnet/DeployShasta.s.sol`
- L2 implementations: `script/layer2/DeployShasta.s.sol`

## Addresses

| Contract                              | Address                                      | Notes                                                                                 |
| ------------------------------------- | -------------------------------------------- | ------------------------------------------------------------------------------------- |
| L1 SignalService proxy                | `0x9e0a24964e5397B566c1ed39258e21aB5E35C77C` | `L1.SIGNAL_SERVICE`                                                                   |
| L1 SignalServiceForkRouter impl (new) | `0x0000000000000000000000000000000000000000` | **Placeholder** — replace with L1 fork router from `DeployShasta.s.sol`               |
| L1 PreconfWhitelist proxy             | `0xFD019460881e6EeC632258222393d5821029b2ac` | rollup resolver name `preconf_whitelist` on L1                                        |
| L1 PreconfWhitelist impl (new)        | `0x0000000000000000000000000000000000000000` | **Placeholder** — replace with L1 deploy output                                       |
| L2 SignalService proxy                | `0x1670000000000000000000000000000000000005` | `L2.SIGNAL_SERVICE` (Taiko mainnet L2)                                                |
| L2 SignalServiceForkRouter impl (new) | `0x0000000000000000000000000000000000000000` | **Placeholder** — replace with L2 fork router from `script/layer2/DeployShasta.s.sol` |
| L2 Anchor proxy                       | `0x1670000000000000000000000000000000010001` | `L2.ANCHOR` (Taiko mainnet L2)                                                        |
| L2 AnchorForkRouter impl (new)        | `0x0000000000000000000000000000000000000000` | **Placeholder** — replace with L2 deploy output                                       |

## Verification & Execution

1. Confirm verified source/config on [Etherscan](https://etherscan.io/) / [Taikoscan](https://taikoscan.io/) for:
   - L1:
     - `SignalService` impl
     - `SignalServiceForkRouter` impl
     - `PreconfWhitelist` impl
     - `CodecOptimized` impl
     - `MainnetInbox` impl / proxy
   - L2:
     - `BondManager` impl / proxy
     - `Anchor` impl
     - `AnchorForkRouter` impl
     - `SignalService` impl
     - `SignalServiceForkRouter` impl
2. Verify proposal calldata: `P=0006 pnpm proposal`.
3. Dry-run on L1: `P=0006 pnpm proposal:dryrun:l1`.
4. Dry-run on L2: `P=0006 pnpm proposal:dryrun:l2`.

The proposal upgrades the UUPS proxies to the already-deployed implementations (L1 directly, L2 via delegate controller message with gas limit `1_500_000`).
