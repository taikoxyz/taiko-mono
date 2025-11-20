# PROPOSAL-0006: Taiko Shasta Fork Upgrade

Upgrade Taiko L1/L2 smart contracts for the Shasta fork: L1 `signal_service` and `preconf_whitelist` proxies, plus L2 `signal_service` and `anchor` proxies. Implementation addresses come from the Shasta deploy scripts (run separately).

## Deployment Scripts

- L1 implementations: `script/layer1/mainnet/DeployShasta.s.sol`
- L2 implementations: `script/layer2/DeployShasta.s.sol`

## Addresses

| Contract                           | Address                                      | Notes                                                                                       |
| ---------------------------------- | -------------------------------------------- | ------------------------------------------------------------------------------------------- |
| L1 SignalService proxy             | `0x9e0a24964e5397B566c1ed39258e21aB5E35C77C` | `L1.SIGNAL_SERVICE`                                                                         |
| New L1 SignalService implementation | `0x0000000000000000000000000000000000000000` | **Placeholder** — replace with `SignalServiceForkRouter` address from `DeployShasta.s.sol` (L1) |
| L1 PreconfWhitelist proxy          | `0xFD019460881e6EeC632258222393d5821029b2ac` | rollup resolver name `preconf_whitelist` on L1                                               |
| New L1 PreconfWhitelist implementation | `0x0000000000000000000000000000000000000000` | **Placeholder** — replace with `DeployShasta.s.sol` (L1) output                             |
| L2 SignalService proxy             | `0x1670000000000000000000000000000000000005` | `L2.SIGNAL_SERVICE` (Taiko mainnet L2)                                                      |
| New L2 SignalService implementation | `0x0000000000000000000000000000000000000000` | **Placeholder** — replace with `SignalServiceForkRouter` address from `script/layer2/DeployShasta.s.sol`  |
| L2 Anchor proxy                    | `0x1670000000000000000000000000000000010001` | `L2.ANCHOR` (Taiko mainnet L2)                                                              |
| New L2 Anchor implementation       | `0x0000000000000000000000000000000000000000` | **Placeholder** — replace with `script/layer2/DeployShasta.s.sol` output                    |

## Verification & Execution

1. Deploy the new SignalService and PreconfWhitelist implementations on L1 via `script/layer1/mainnet/DeployShasta.s.sol`, capture the emitted implementation addresses.
2. Deploy the new SignalService and Anchor implementations on L2 via `script/layer2/DeployShasta.s.sol`, capture the emitted implementation addresses.
3. Verify proposal calldata: `P=0006 pnpm proposal`.
4. Dry-run on L1: `P=0006 pnpm proposal:dryrun:l1`.
5. Dry-run on L1: `P=0006 pnpm proposal:dryrun:l2`.

No deployment is performed inside the proposal; it upgrades the UUPS proxies to the pre-deployed implementations (L1 directly, L2 via delegate controller message with gas limit `1_500_000`).
