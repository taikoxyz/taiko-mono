# PROPOSAL-0014: Enable raiko2 v0.2.0 SP1 Shasta Digests and Disable Legacy SP1

## Enable vs Disable

This DAO `Execute` bundle contains two SP1-only intent blocks:

| Block       | Predicate                       | Meaning                                                                                                                               |
| ----------- | ------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| **ENABLE**  | `setProgramTrusted(..., true)`  | Registers [raiko2 `v0.2.0`](https://github.com/taikoxyz/raiko2/releases/tag/v0.2.0) SP1 guest identifiers on the Shasta SP1 verifier. |
| **DISABLE** | `setProgramTrusted(..., false)` | Revokes legacy SP1 fingerprints that Proposal0009/0010 registered on the Shasta SP1 verifier.                                         |

**Scope:** this proposal only calls `SP1_SHASTA_VERIFIER`. RISC0 image IDs and SGX `setMrEnclave` trust are intentionally unchanged.

**Execution order:** ENABLE first (**4**), then DISABLE (**8**); one atomic DAO `Execute`.

---

## Where To Read What

| Artifact                                             | Purpose                                                                                        |
| ---------------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| **This file (`Proposal0014.md`)**                    | Human-facing spec, constants, regeneration steps, and verification checklist.                  |
| [`Proposal0014.s.sol`](./Proposal0014.s.sol)         | Source of truth for on-chain constants and action encoding.                                    |
| [`Proposal0014.action.md`](./Proposal0014.action.md) | Generated DAO `Execute` calldata. Regenerate with `P=0014 pnpm proposal`; do not hand-edit it. |

---

## Executive Summary

This proposal enables the SP1 guest digests from [raiko2 `v0.2.0`](https://github.com/taikoxyz/raiko2/releases/tag/v0.2.0) on the Shasta SP1 verifier, and disables legacy SP1 program identifiers previously enabled under [`Proposal0009`](./Proposal0009.s.sol) and [`Proposal0010`](./Proposal0010.s.sol).

It executes **12 L1 actions** via the DAO Controller: **4 × true**, then **8 × false**. There are no L2 actions, no contract upgrades, no RISC0 allowlist changes, and no SGX / attestation changes.

---

## Technical Specification

### Verifier Target

| Constant              | Address                                      |
| --------------------- | -------------------------------------------- |
| `SP1_SHASTA_VERIFIER` | `0x96337327648dcFA22b014009cf10A2D5E2F305f6` |

### ENABLE - SP1 Guest Digests

These values must match [raiko2 v0.2.0 - ZK Guest Digests](https://github.com/taikoxyz/raiko2/releases/tag/v0.2.0).

| Constant (`Proposal0014.s.sol`)   | Role on release page          | Value (`bytes32`)                                                    |
| --------------------------------- | ----------------------------- | -------------------------------------------------------------------- |
| `SP1_PROPOSAL_VKEY_BN256`         | sp1 proposal vk_bn254         | `0x00cbb3390c27696467170dd5dac119dc7d579da7d069afae078806f9d6f47580` |
| `SP1_PROPOSAL_VKEY_HASH_BYTES`    | sp1 proposal vk_hash_bytes    | `0x65d99c8609da591962e1babb2c119dc76abced3e41a6beb80f100df356f47580` |
| `SP1_AGGREGATION_VKEY_BN256`      | sp1 aggregation vk_bn254      | `0x001e209da7d70983b826d88cb227861d1263435fe54fad6e4e5d83c593ee94c5` |
| `SP1_AGGREGATION_VKEY_HASH_BYTES` | sp1 aggregation vk_hash_bytes | `0x0f104ed375c260ee04db1196227861d1131a1aff153eb5b91cbb078b13ee94c5` |

### DISABLE - Legacy SP1 Identifiers

These rows mirror historic `setProgramTrusted(..., true)` registrations. No historic SGX entries are included.

**Proposal0009** (SP1 subset only):

| Solidity constant (`Proposal0014.s.sol`) | Hex `bytes32`                                                        |
| ---------------------------------------- | -------------------------------------------------------------------- |
| `SP1_P9_BATCH_VKEY_BN256`                | `0x0026ff63d649779a5dbc88c3359ab83399a21fb6ef9b7ec082f77a8a465806e7` |
| `SP1_P9_BATCH_VKEY_HASH_BYTES`           | `0x137fb1eb125de6973791186659ab83394d10fdb73e6dfb0205eef514465806e7` |
| `SP1_P9_AGG_VKEY_BN256`                  | `0x008e24716118be9594358d8882d93d5425f0827cf0a7a4fd0ea2fc4414debfe7` |
| `SP1_P9_AGG_VKEY_HASH_BYTES`             | `0x471238b0462fa56506b1b1102d93d5422f8413e7429e93f41d45f88814debfe7` |

**Proposal0010** (SP1 subset only):

| Solidity constant (`Proposal0014.s.sol`) | Hex `bytes32`                                                        |
| ---------------------------------------- | -------------------------------------------------------------------- |
| `SP1_P10_BATCH_VKEY_BN256`               | `0x0079682c7b5af614273de79761aaad20d1c8e1a65091388b81be836632d382f8` |
| `SP1_P10_BATCH_VKEY_HASH_BYTES`          | `0x3cb4163d56bd850967bcf2ec1aaad20d0e470d324244e22e037d06cc32d382f8` |
| `SP1_P10_AGG_VKEY_BN256`                 | `0x0002ac747570512099ca19c17f5a3b9f39697e5617a19ff2f2b2464229a50c7c` |
| `SP1_P10_AGG_VKEY_HASH_BYTES`            | `0x01563a3a5c1448263943382f75a3b9f34b4bf2b05e867fcb65648c8429a50c7c` |

### L1 Actions

**12 total:**

- **ENABLE (4):** `true` for the four raiko2 v0.2.0 SP1 values.
- **DISABLE (8):** `false` for the eight legacy SP1 values from Proposal0009/0010.

Concrete ordering matches [`Proposal0014.s.sol`](./Proposal0014.s.sol).

---

## External Verification

### Objective

Approvers distinguish two evidence tracks:

**ENABLE (four values):** prove that each SP1 `bytes32` in the ENABLE block is produced by building or attesting raiko2 guests at [`v0.2.0`](https://github.com/taikoxyz/raiko2/releases/tag/v0.2.0). The release page is a sanity cross-check; reproducible output or CI logs for the tag are the stronger evidence.

**DISABLE (eight values):** verify that each legacy `bytes32` matches historical SP1 `setProgramTrusted(..., true)` payloads from `Proposal0009.s.sol` and `Proposal0010.s.sol`. No raiko rebuild is required for the DISABLE list.

### Canonical Release Cut

| Field                | Value                                                  |
| -------------------- | ------------------------------------------------------ |
| `RAIKO2_REPO`        | `https://github.com/taikoxyz/raiko2.git`               |
| `RAIKO2_TAG`         | `v0.2.0`                                               |
| `RAIKO2_RELEASE_URL` | https://github.com/taikoxyz/raiko2/releases/tag/v0.2.0 |
| `RAIKO2_TREE_URL`    | https://github.com/taikoxyz/raiko2/tree/v0.2.0         |

Resolve the tag locally before attesting outputs:

```bash
git clone --branch "$RAIKO2_TAG" --depth 1 "$RAIKO2_REPO" raiko2-verify
cd raiko2-verify
git rev-parse HEAD
```

### Normative ENABLE Digests

```yaml
proposal_0014_expected_sp1_digests:
  sp1_proposal_vk_bn254: "0x00cbb3390c27696467170dd5dac119dc7d579da7d069afae078806f9d6f47580"
  sp1_proposal_vk_hash_bytes: "0x65d99c8609da591962e1babb2c119dc76abced3e41a6beb80f100df356f47580"
  sp1_aggregation_vk_bn254: "0x001e209da7d70983b826d88cb227861d1263435fe54fad6e4e5d83c593ee94c5"
  sp1_aggregation_vk_hash_bytes: "0x0f104ed375c260ee04db1196227861d1131a1aff153eb5b91cbb078b13ee94c5"
```

Mapping to Solidity symbols in `Proposal0014.s.sol`: `SP1_PROPOSAL_VKEY_BN256`, `SP1_PROPOSAL_VKEY_HASH_BYTES`, `SP1_AGGREGATION_VKEY_BN256`, `SP1_AGGREGATION_VKEY_HASH_BYTES`.

### Pass / Fail Gates

| Gate                    | Check                                                                                                                             |
| ----------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| **G1**                  | `RAIKO2_TAG` checks out to the commit associated with GitHub's `v0.2.0` release.                                                  |
| **G2**                  | Reproduced or CI-attested build emits the four SP1 ENABLE digests; each equals the YAML entry and a line in `Proposal0014.s.sol`. |
| **G3**                  | Same four values appear on the raiko2 v0.2.0 release page under ZK Guest Digests.                                                 |
| **G4** (pre-execution)  | Each legacy SP1 `bytes32` in DISABLE is currently trusted on-chain or otherwise reconciled before approval.                       |
| **G5** (post-execution) | ENABLE SP1 digests read `true`; DISABLE SP1 digests read `false` through `isProgramTrusted(bytes32)`.                             |

Fail closed if ENABLE reproduction or release parity fails. If any legacy marker is already false before execution, reconcile upstream revocations before approving.

---

## How To Run

Environment: monorepo root with `pnpm` installed; Solidity script uses `FOUNDRY_PROFILE=layer1`.

### Step 1 - Install Dependencies

```bash
pnpm install
```

### Step 2 - Compile

```bash
cd packages/protocol
FOUNDRY_PROFILE=layer1 forge build --contracts script/layer1/proposals/Proposal0014.s.sol
```

### Step 3 - Regenerate DAO Action Markdown

```bash
cd packages/protocol
P=0014 pnpm proposal
```

Expected outcome:

- Console prints the DAO `Execute` calldata snippet.
- `packages/protocol/script/layer1/proposals/Proposal0014.action.md` is overwritten.
- Commit the regenerated action markdown together with Solidity changes.

### Step 4 - Dry-Run On L1

```bash
cd packages/protocol
P=0014 pnpm proposal:dryrun:l1
```

Expected: the script completes per `BuildProposal` / controller dryrun behavior.

---

## Verification Checklist

### A. Before DAO Submission / Before Merging

1. Complete the external verification gates G1-G5.
2. Compare the four SP1 v0.2.0 ENABLE values against the raiko2 release page and `Proposal0014.s.sol`.
3. Confirm the eight DISABLE values match Proposal0009/0010 SP1 registrations.
4. Run `P=0014 pnpm proposal` after any `.s.sol` change.
5. Run the L1 dryrun with `P=0014 pnpm proposal:dryrun:l1`.

### B. After Governance Execution

The SP1 verifier exposes `isProgramTrusted(bytes32) -> bool`.

Replace `$RPC_URL` with a trustworthy mainnet JSON-RPC endpoint.

**ENABLE - raiko2 v0.2.0 SP1 values, expect `true` after execution:**

```bash
S=0x96337327648dcFA22b014009cf10A2D5E2F305f6

cast call "$S" 'isProgramTrusted(bytes32)(bool)' \
  0x00cbb3390c27696467170dd5dac119dc7d579da7d069afae078806f9d6f47580 --rpc-url "$RPC_URL"
cast call "$S" 'isProgramTrusted(bytes32)(bool)' \
  0x65d99c8609da591962e1babb2c119dc76abced3e41a6beb80f100df356f47580 --rpc-url "$RPC_URL"
cast call "$S" 'isProgramTrusted(bytes32)(bool)' \
  0x001e209da7d70983b826d88cb227861d1263435fe54fad6e4e5d83c593ee94c5 --rpc-url "$RPC_URL"
cast call "$S" 'isProgramTrusted(bytes32)(bool)' \
  0x0f104ed375c260ee04db1196227861d1131a1aff153eb5b91cbb078b13ee94c5 --rpc-url "$RPC_URL"
```

**DISABLE - Proposal0009 / Proposal0010 legacy SP1 values, expect `false` after execution:**

```bash
cast call "$S" 'isProgramTrusted(bytes32)(bool)' \
  0x0026ff63d649779a5dbc88c3359ab83399a21fb6ef9b7ec082f77a8a465806e7 --rpc-url "$RPC_URL"
cast call "$S" 'isProgramTrusted(bytes32)(bool)' \
  0x137fb1eb125de6973791186659ab83394d10fdb73e6dfb0205eef514465806e7 --rpc-url "$RPC_URL"
cast call "$S" 'isProgramTrusted(bytes32)(bool)' \
  0x008e24716118be9594358d8882d93d5425f0827cf0a7a4fd0ea2fc4414debfe7 --rpc-url "$RPC_URL"
cast call "$S" 'isProgramTrusted(bytes32)(bool)' \
  0x471238b0462fa56506b1b1102d93d5422f8413e7429e93f41d45f88814debfe7 --rpc-url "$RPC_URL"
cast call "$S" 'isProgramTrusted(bytes32)(bool)' \
  0x0079682c7b5af614273de79761aaad20d1c8e1a65091388b81be836632d382f8 --rpc-url "$RPC_URL"
cast call "$S" 'isProgramTrusted(bytes32)(bool)' \
  0x3cb4163d56bd850967bcf2ec1aaad20d0e470d324244e22e037d06cc32d382f8 --rpc-url "$RPC_URL"
cast call "$S" 'isProgramTrusted(bytes32)(bool)' \
  0x0002ac747570512099ca19c17f5a3b9f39697e5617a19ff2f2b2464229a50c7c --rpc-url "$RPC_URL"
cast call "$S" 'isProgramTrusted(bytes32)(bool)' \
  0x01563a3a5c1448263943382f75a3b9f34b4bf2b05e867fcb65648c8429a50c7c --rpc-url "$RPC_URL"
```

---

## Security Contacts

- security@taiko.xyz
