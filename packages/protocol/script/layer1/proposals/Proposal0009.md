# PROPOSAL-0009: Upgrade Protocol to Shasta + ZK Verifiers + SGX MR_ENCLAVE

## Executive Summary

This proposal (1) upgrades Taiko mainnet protocol contracts to activate Shasta on L1 and L2, (2) registers raiko zk:v1.16.0 RISC0/SP1 image and program IDs on **Shasta** verifiers only, and (3) updates SGX MR_ENCLAVE values to raiko v1.16.0 (non-edmm + edmm for raiko; only non-edmm for gaiko).

It executes **13 L1 actions** from the DAO Controller and **2 L2 actions** through the DelegateController bridge flow.

- **Shasta**: Next generation protocol; see [Achieving stage 1: Shasta is almost here](https://paragraph.com/@taiko-labs/achieving-stage-1-shasta-is-almost-here).
- **ZK**: Shasta only; image/program IDs from [raiko RELEASE zk:v1.16.0](https://github.com/taikoxyz/raiko/pull/674).
- **SGX**: MR_ENCLAVE from [raiko RELEASE v1.16.0 and v1.16.0-edmm](https://github.com/taikoxyz/raiko/pull/674).

## Technical Specification

### Address Constants

**Shasta / protocol**

| Constant                        | Value                                        | Notes                                  |
| ------------------------------- | -------------------------------------------- | -------------------------------------- |
| `PRECONF_WHITELIST_NEW_IMPL`    | `0xDBae46E35C18719E6c78aaBF9c8869c4eC84c149` | L1 Shasta `preconf_whitelist`          |
| `PROVER_WHITELIST_PROXY`        | `0xEa798547d97e345395dA071a0D7ED8144CD612Ae` | L1 Shasta `prover_whitelist_proxy`     |
| `SIGNAL_SERVICE_FORK_ROUTER_L1` | `0x6a4B15E4b0296B2ECE03Ee9Ed74E4A3E3ECA68D6` | L1 Shasta `signal_service_fork_router` |
| `PACAYA_MAINNET_INBOX_NEW_IMPL` | `0x38Dd73fed93F8051E7A0dDd6FB3b9E7C25668187` | L1 Pacaya mainnet Inbox implementation |
| `ANCHOR_FORK_ROUTER_L2`         | `0x38e4A497aD70aa0581BAc29747b0Ea7a53258585` | L2 Shasta `anchor_fork_router`         |
| `SIGNAL_SERVICE_FORK_ROUTER_L2` | `0x2987F6Bef39b03F8522EC38B36aF0f7422938EAb` | L2 Shasta `signal_service_fork_router` |

**ZK verifiers (taiko_mainnet, Shasta only; raiko zk:v1.16.0)**

| Constant                | Value                                        |
| ----------------------- | -------------------------------------------- |
| `SP1_SHASTA_VERIFIER`   | `0x96337327648dcFA22b014009cf10A2D5E2F305f6` |
| `RISC0_SHASTA_VERIFIER` | `0x059dAF31F571da48Ab4e74Ae12F64f907681Cd8b` |

**SGX attesters**

| Constant           | Value                                        |
| ------------------ | -------------------------------------------- |
| `SGXRETH_ATTESTER` | `0x8d7C954960a36a7596d7eA4945dDf891967ca8A3` |
| `SGXGETH_ATTESTER` | `0x0ffa4A625ED9DB32B70F99180FD00759fc3e9261` |

### L1 Actions (13 total)

**Shasta / protocol (4)**

1. Upgrade `PRECONF_WHITELIST` proxy (`0xFD019460881e6EeC632258222393d5821029b2ac`) to `PRECONF_WHITELIST_NEW_IMPL`.
2. Call `acceptOwnership()` on `PROVER_WHITELIST_PROXY`.
3. Upgrade `SIGNAL_SERVICE` proxy (`0x9e0a24964e5397B566c1ed39258e21aB5E35C77C`) to `SIGNAL_SERVICE_FORK_ROUTER_L1`.
4. Upgrade L1 `INBOX` proxy to `PACAYA_MAINNET_INBOX_NEW_IMPL`.

**ZK verifiers (6)** — Shasta only. Register proof image/program IDs so Shasta verifiers accept raiko zk:v1.16.0 proofs: _batch_ (per-block) and _shasta-aggregation_ (aggregated). RISC0: 2 image IDs. SP1: 4 program IDs (2 per proof type). [PR 674](https://github.com/taikoxyz/raiko/pull/674).

**SGX (3)** — `setMrEnclave(bytes32,bool)` on attesters: raiko v1.16.0 non-edmm + edmm on `SGXRETH_ATTESTER`; gaiko v1.16.0 non-edmm on `SGXGETH_ATTESTER`.

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
