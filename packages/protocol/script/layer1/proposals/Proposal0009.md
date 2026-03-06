# PROPOSAL-0009: Upgrade Protocol to Shasta

## Executive Summary

This proposal upgrades Taiko mainnet protocol contracts to activate Shasta-related components on both L1 and L2.
It executes three L1 actions directly from the DAO Controller and two L2 actions through the DelegateController bridge flow.

Shasta is the next generation protocol design for Taiko, and has been tested, audited and deployed on internal devnets and Hoodi already.
You can read more about it [here](https://paragraph.com/@taiko-labs/achieving-stage-1-shasta-is-almost-here).

## Technical Specification

### Address Constants

| Constant                        | Value                                        | Notes                                  |
| ------------------------------- | -------------------------------------------- | -------------------------------------- |
| `PRECONF_WHITELIST_NEW_IMPL`    | `0xDBae46E35C18719E6c78aaBF9c8869c4eC84c149` | L1 Shasta `preconf_whitelist`          |
| `PROVER_WHITELIST_PROXY`        | `0xEa798547d97e345395dA071a0D7ED8144CD612Ae` | L1 Shasta `prover_whitelist_proxy`     |
| `SIGNAL_SERVICE_FORK_ROUTER_L1` | `0x6a4B15E4b0296B2ECE03Ee9Ed74E4A3E3ECA68D6` | L1 Shasta `signal_service_fork_router` |
| `ANCHOR_FORK_ROUTER_L2`         | `0x38e4A497aD70aa0581BAc29747b0Ea7a53258585` | L2 Shasta `anchor_fork_router`         |
| `SIGNAL_SERVICE_FORK_ROUTER_L2` | `0x2987F6Bef39b03F8522EC38B36aF0f7422938EAb` | L2 Shasta `signal_service_fork_router` |

### L1 Actions

1. Upgrade `PRECONF_WHITELIST` proxy (`0xFD019460881e6EeC632258222393d5821029b2ac`) to `PRECONF_WHITELIST_NEW_IMPL`.
2. Call `acceptOwnership()` on `PROVER_WHITELIST_PROXY`.
3. Upgrade `SIGNAL_SERVICE` proxy (`0x9e0a24964e5397B566c1ed39258e21aB5E35C77C`) to `SIGNAL_SERVICE_FORK_ROUTER_L1`.

### L2 Actions (via bridge + DelegateController)

1. Upgrade `ANCHOR` proxy (`0x1670000000000000000000000000000000010001`) to `ANCHOR_FORK_ROUTER_L2`.
2. Upgrade `SIGNAL_SERVICE` proxy (`0x1670000000000000000000000000000000000005`) to `SIGNAL_SERVICE_FORK_ROUTER_L2`.

Execution parameters:

- `l2ExecutionId`: `0`
- `l2GasLimit`: `5_000_000`

## Verification

Before submission:

1. Verify deployed bytecode exists for each configured address:

   ```bash
   cast code <ADDRESS> --rpc-url <RPC_URL>
   ```

2. Generate proposal calldata:

   ```bash
   P=0009 pnpm proposal
   ```

3. Dryrun on L1:

   ```bash
   P=0009 pnpm proposal:dryrun:l1
   ```

4. Dryrun on L2:

   ```bash
   P=0009 pnpm proposal:dryrun:l2
   ```

After execution:

1. Confirm `owner()` on `PROVER_WHITELIST_PROXY` is `controller.taiko.eth` (`0x75Ba76403b13b26AD1beC70D6eE937314eeaCD0a`).
2. Confirm each upgraded proxy points to its intended implementation (EIP-1967 implementation slot).

## Security Contacts

- security@taiko.xyz
