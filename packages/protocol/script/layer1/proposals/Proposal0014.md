# PROPOSAL-0014: Register raiko2 v0.2.0 Shasta ZK Verifier Digests

## Where to read what

| Artifact                                             | Purpose                                                                                                                                                                                                                                                                                  |
| ---------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **This file (`Proposal0014.md`)**                    | Human-facing spec: rationale, constants table, **how to regenerate calldata**, **verification checklist** (before and after DAO execution). Reviewers should start here.                                                                                                                 |
| [`Proposal0014.s.sol`](./Proposal0014.s.sol)         | Source of truth for on-chain constants and action encoding (`abi.encodeCall`). Any change to digests happens here first.                                                                                                                                                                 |
| [`Proposal0014.action.md`](./Proposal0014.action.md) | **Generated** DAO `Execute` calldata. Run `P=0014 pnpm proposal` from `packages/protocol` and commit the output. Do **not** hand-edit this file or it may desync from the Solidity script (same concern as discussed on [PR #21661](https://github.com/taikoxyz/taiko-mono/pull/21661)). |

**Audience:** Core contributors, **external Security Council / reviewers**, and **automated agents** reproducing raiko2 release artifacts. External parties should treat **§ External verification** as the approval gate; **§ Verification checklist** adds taiko-mono packaging and on-chain read steps.

---

## Executive Summary

This proposal **additively** registers the RISC Zero and SP1 guest digests from **[raiko2 v0.2.0](https://github.com/taikoxyz/raiko2/releases/tag/v0.2.0)** on the existing **Shasta-only** verifiers on Ethereum mainnet (`RISC0_SHASTA_VERIFIER`, `SP1_SHASTA_VERIFIER`).

It executes **6 L1 actions** via the DAO Controller. There are **no** L2 actions, **no** contract upgrades, and **no** SGX / attestation changes.

The structure matches the DAO registration style used for raiko2 ZK digests (see [PR #21661 — Proposal0013](https://github.com/taikoxyz/taiko-mono/pull/21661); numbering on `main` may differ depending on merge order). Earlier trusted IDs from [`Proposal0009`](./Proposal0009.s.sol), [`Proposal0010`](./Proposal0010.s.sol), and any prior digest proposal **stay** trusted unless a future proposal sets them to `false`.

---

## Rationale

- Provers produced from **[raiko2 v0.2.0](https://github.com/taikoxyz/raiko2/releases/tag/v0.2.0)** emit new RISC0 `image_id` and SP1 program verification key identifiers. Until those identifiers are trusted on-chain, proofs from this release cannot pass verification.

- Scope is intentional: **Shasta verifier proxies only**, **additive** `setImageIdTrusted` / `setProgramTrusted(..., true)`.

Release highlights relevant to infra (see [release notes](https://github.com/taikoxyz/raiko2/releases/tag/v0.2.0)): SP1 proving stack **6.1.0**, Boundless-related aggregation path consolidation, etc. Digest values below are copied from that release page.

---

## Technical Specification

### Verifier targets

| Constant                | Address                                      |
| ----------------------- | -------------------------------------------- |
| `RISC0_SHASTA_VERIFIER` | `0x059dAF31F571da48Ab4e74Ae12F64f907681Cd8b` |
| `SP1_SHASTA_VERIFIER`   | `0x96337327648dcFA22b014009cf10A2D5E2F305f6` |

### Guest digests (must match [raiko2 v0.2.0 — ZK Guest Digests](https://github.com/taikoxyz/raiko2/releases/tag/v0.2.0))

| Constant (`Proposal0014.s.sol`)   | Role on release page          | Value (`bytes32`)                                                    |
| --------------------------------- | ----------------------------- | -------------------------------------------------------------------- |
| `RISC0_PROPOSAL_IMAGE_ID`         | risc0 proposal                | `0x588c81521db5bef5e07f5beab37f1f0b2bba925ac82e733db7cc72e046362754` |
| `RISC0_AGGREGATION_IMAGE_ID`      | risc0 aggregation             | `0x91ddc48054ff4ec62a93bfa0583582d0e04de6ab3928e51e0ea3ee523fee129f` |
| `SP1_PROPOSAL_VKEY_BN256`         | sp1 proposal vk_bn254         | `0x00cbb3390c27696467170dd5dac119dc7d579da7d069afae078806f9d6f47580` |
| `SP1_PROPOSAL_VKEY_HASH_BYTES`    | sp1 proposal vk_hash_bytes    | `0x65d99c8609da591962e1babb2c119dc76abced3e41a6beb80f100df356f47580` |
| `SP1_AGGREGATION_VKEY_BN256`      | sp1 aggregation vk_bn254      | `0x001e209da7d70983b826d88cb227861d1263435fe54fad6e4e5d83c593ee94c5` |
| `SP1_AGGREGATION_VKEY_HASH_BYTES` | sp1 aggregation vk_hash_bytes | `0x0f104ed375c260ee04db1196227861d1131a1aff153eb5b91cbb078b13ee94c5` |

### L1 actions (6 total)

1. `Risc0Verifier.setImageIdTrusted(RISC0_PROPOSAL_IMAGE_ID, true)` → `RISC0_SHASTA_VERIFIER`.
2. `Risc0Verifier.setImageIdTrusted(RISC0_AGGREGATION_IMAGE_ID, true)` → `RISC0_SHASTA_VERIFIER`.
3. `SP1Verifier.setProgramTrusted(SP1_PROPOSAL_VKEY_BN256, true)` → `SP1_SHASTA_VERIFIER`.
4. `SP1Verifier.setProgramTrusted(SP1_PROPOSAL_VKEY_HASH_BYTES, true)` → `SP1_SHASTA_VERIFIER`.
5. `SP1Verifier.setProgramTrusted(SP1_AGGREGATION_VKEY_BN256, true)` → `SP1_SHASTA_VERIFIER`.
6. `SP1Verifier.setProgramTrusted(SP1_AGGREGATION_VKEY_HASH_BYTES, true)` → `SP1_SHASTA_VERIFIER`.

---

## External verification (independent reviewers & agents)

### Objective (approval gate)

Before approving this proposal, an external verifier **MUST** establish that the **six `bytes32` values** registered on L1 are exactly those produced by **building the ZK guest artifacts from the same release cut** as [raiko2 `v0.2.0`](https://github.com/taikoxyz/raiko2/releases/tag/v0.2.0). Matching the GitHub release **table alone** is a cross-check; **reproducible output from the tag** (or bit-identical CI logs from that tag) is the stronger bar.

### Canonical release cut (machine-oriented)

Use these as stable inputs; **resolve the tag to a commit** locally—do not assume a hard-coded commit in this doc if the tag ever moves.

| Field                | Value                                                  |
| -------------------- | ------------------------------------------------------ |
| `RAIKO2_REPO`        | `https://github.com/taikoxyz/raiko2.git`               |
| `RAIKO2_TAG`         | `v0.2.0`                                               |
| `RAIKO2_RELEASE_URL` | https://github.com/taikoxyz/raiko2/releases/tag/v0.2.0 |
| `RAIKO2_TREE_URL`    | https://github.com/taikoxyz/raiko2/tree/v0.2.0         |

Record `RAIKO2_COMMIT` after checkout:

```bash
git clone --branch "$RAIKO2_TAG" --depth 1 "$RAIKO2_REPO" raiko2-verify
cd raiko2-verify
git rev-parse HEAD   # this is RAIKO2_COMMIT; compare with the commit GitHub shows for the release/tag
```

If `RAIKO2_COMMIT` does not match the commit associated with `v0.2.0` on GitHub, **stop** and reconcile (detached tag, mirror lag, or wrong ref).

### Normative digests for this proposal (must all match)

Values **MUST** equal each of: (1) your reproduced build output, (2) the [v0.2.0 release **ZK Guest Digests** table](https://github.com/taikoxyz/raiko2/releases/tag/v0.2.0), (3) [`Proposal0014.s.sol`](./Proposal0014.s.sol). Compare as **case-insensitive hex** for `0x` + 64 hex digits.

```yaml
# Normative bytes32 (64 hex chars after 0x). For agents: parse and compare to build output.
proposal_0014_expected_guest_digests:
  risc0_proposal_image_id: "0x588c81521db5bef5e07f5beab37f1f0b2bba925ac82e733db7cc72e046362754"
  risc0_aggregation_image_id: "0x91ddc48054ff4ec62a93bfa0583582d0e04de6ab3928e51e0ea3ee523fee129f"
  sp1_proposal_vk_bn254: "0x00cbb3390c27696467170dd5dac119dc7d579da7d069afae078806f9d6f47580"
  sp1_proposal_vk_hash_bytes: "0x65d99c8609da591962e1babb2c119dc76abced3e41a6beb80f100df356f47580"
  sp1_aggregation_vk_bn254: "0x001e209da7d70983b826d88cb227861d1263435fe54fad6e4e5d83c593ee94c5"
  sp1_aggregation_vk_hash_bytes: "0x0f104ed375c260ee04db1196227861d1131a1aff153eb5b91cbb078b13ee94c5"
```

Mapping to **Solidity** symbols in `Proposal0014.s.sol`: `RISC0_PROPOSAL_IMAGE_ID`, `RISC0_AGGREGATION_IMAGE_ID`, `SP1_PROPOSAL_VKEY_BN256`, `SP1_PROPOSAL_VKEY_HASH_BYTES`, `SP1_AGGREGATION_VKEY_BN256`, `SP1_AGGREGATION_VKEY_HASH_BYTES`.

### Reproduction procedure (follow raiko2 at `v0.2.0`)

The exact shell commands depend on how **taikoxyz/raiko2** documents guest builds at that tag. Verifiers **SHALL**:

1. **Read** at minimum `README.md` (and any `docs/` or `CONTRIBUTING.md` linked from it) **at** `RAIKO2_TAG`.
2. **Inspect** CI under [`.github/workflows/`](https://github.com/taikoxyz/raiko2/tree/v0.2.0/.github/workflows) for the **job that builds guests / prints image IDs and SP1 vkeys** (search for `image_id`, `guest`, `sp1`, `risc0`, `digest`, `vk_bn254`, `hash_bytes`). Re-run the same command sequence in a clean environment, or treat **published CI logs for a workflow run on `RAIKO2_COMMIT`** as equivalent if your policy allows it.
3. **Extract** from build output (or CI log) the six identifiers corresponding to:
   - RISC0 **proposal** guest `image_id`
   - RISC0 **aggregation** guest `image_id`
   - SP1 **proposal** `vk_bn254` and `vk_hash_bytes`
   - SP1 **aggregation** `vk_bn254` and `vk_hash_bytes`
4. **Assert** all six equal the YAML block above (and thus the release page and `Proposal0014.s.sol`).

If the repository does not print all six in one command, use the **documented** split steps (e.g. separate RISC0 vs SP1 targets); the union must still match the YAML.

### Pass / fail gates (agent checklist)

| Gate                    | Check                                                                                                                                                                                                                                   |
| ----------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **G1**                  | `RAIKO2_TAG` checks out to `RAIKO2_COMMIT` consistent with GitHub’s `v0.2.0` release.                                                                                                                                                   |
| **G2**                  | Reproduced (or CI-attested) build emits **six** digests; each equals the YAML entry **and** a line in [`Proposal0014.s.sol`](./Proposal0014.s.sol).                                                                                     |
| **G3**                  | Same six values appear on [raiko2 v0.2.0 release](https://github.com/taikoxyz/raiko2/releases/tag/v0.2.0) under **ZK Guest Digests** (wording may differ; compare by role: proposal vs aggregation, RISC0 vs SP1, bn254 vs hash_bytes). |
| **G4** (post-execution) | On Ethereum mainnet, `isImageTrusted` / `isProgramTrusted` return `true` for each digest (see **§ Verification checklist B**).                                                                                                          |

**Fail closed:** if any gate fails, do not approve until taiko-mono or raiko2 release documentation is corrected.

### What this proposal does _not_ require external verifiers to do

- Rebuild **taiko-mono** protocol contracts to “derive” digests (digests come from **raiko2** guests).
- Trust **only** this Markdown file: always anchor on **tag + raiko2 build** and on-chain constants in `.s.sol`.

---

## How to run (local / CI)

Environment: **repo root monorepo** with `pnpm` installed; Solidity script uses **`FOUNDRY_PROFILE=layer1`** (wired in npm scripts).

### Step 1 — Install deps (once per machine)

From monorepo root:

```bash
pnpm install
```

### Step 2 — Compile (`packages/protocol`)

```bash
cd packages/protocol
FOUNDRY_PROFILE=layer1 forge build --contracts script/layer1/proposals/Proposal0014.s.sol
```

(Optional sanity: full `pnpm compile:l1`.)

### Step 3 — Regenerate DAO action markdown (**required** after any `.s.sol` change)

```bash
cd packages/protocol
P=0014 pnpm proposal
```

Expected outcome:

- Console prints the DAO `Execute` calldata snippet.
- File `packages/protocol/script/layer1/proposals/Proposal0014.action.md` is **overwritten**.
- Diff the regenerated `Proposal0014.action.md` with git; commit it together with Solidity changes.

### Step 4 — Dry-run on L1 (mainnet RPC)

Uses the npm script wrapper (Ethereum mainnet `chain-id=1`; RPC is pinned in [`packages/protocol/package.json`](../../../package.json) `proposal:dryrun:l1`):

```bash
cd packages/protocol
P=0014 pnpm proposal:dryrun:l1
```

Expected: the script completes per `BuildProposal` / controller `dryrun` behavior (successful dryrun completes with `DryrunSucceeded()` on that code path).

To use a **different RPC** (fork or paid endpoint), invoke `forge script` manually with `--rpc-url` per your ops policy, matching `MODE=l1dryrun` and `--chain-id=1` behavior from the npm script.

---

## Verification checklist

### A. Before DAO submission / before merging this PR

0. **External gate** — Complete **§ External verification** (reproduction + YAML equality). Approvers relying on automation should implement **G1–G3** as machine checks where possible.

1. **Release parity (manual)** — Open [raiko2 v0.2.0](https://github.com/taikoxyz/raiko2/releases/tag/v0.2.0). Copy each line under **ZK Guest Digests** and confirm **byte-for-byte** equality with [`Proposal0014.s.sol`](./Proposal0014.s.sol). Use this mapping between release wording and Solidity names:

   - Release “risc0 proposal `image_id`” → `RISC0_PROPOSAL_IMAGE_ID`
   - Release “risc0 aggregation `image_id`” → `RISC0_AGGREGATION_IMAGE_ID`
   - Release “sp1 proposal `vk_bn254`” → `SP1_PROPOSAL_VKEY_BN256`
   - Release “sp1 proposal `vk_hash_bytes`” → `SP1_PROPOSAL_VKEY_HASH_BYTES`
   - Release “sp1 aggregation `vk_bn254`” → `SP1_AGGREGATION_VKEY_BN256`
   - Release “sp1 aggregation `vk_hash_bytes`” → `SP1_AGGREGATION_VKEY_HASH_BYTES`

2. **Release tag metadata** — On the release page, confirm tag **v0.2.0** and referenced commit (**e.g. `f5d4665`** on the release timeline) matches the build you intend to attest (if release is retagged, re-verify digests).

3. **Rebuild `Proposal0014.action.md` from source** — After checking constants, run **Step 3** above so `Proposal0014.action.md` cannot drift from `.s.sol`.

4. **L1 dryrun** — Run **Step 4** above on a workstation with Foundry configured.

### B. After governance execution on mainnet (`cast read`)

The verifiers expose public getters:

- RISC0: `isImageTrusted(bytes32) → bool`
- SP1: `isProgramTrusted(bytes32) → bool`

Replace `$RPC_URL` with a trustworthy mainnet JSON-RPC endpoint.

**RISC0**

```bash
R=0x059dAF31F571da48Ab4e74Ae12F64f907681Cd8b

cast call "$R" 'isImageTrusted(bytes32)(bool)' \
  0x588c81521db5bef5e07f5beab37f1f0b2bba925ac82e733db7cc72e046362754 --rpc-url "$RPC_URL"
cast call "$R" 'isImageTrusted(bytes32)(bool)' \
  0x91ddc48054ff4ec62a93bfa0583582d0e04de6ab3928e51e0ea3ee523fee129f --rpc-url "$RPC_URL"
```

**SP1**

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

Each call should return `true`.

### C. Reproduce digests (required for external sign-off; optional for merge-only QA)

Fully specified under **§ External verification**. Shortcut: clone [taikoxyz/raiko2](https://github.com/taikoxyz/raiko2) at **`v0.2.0`**, follow README / docs / workflows at that tag, extract the six guest identifiers, and assert equality with the **YAML normative block** above and [`Proposal0014.s.sol`](./Proposal0014.s.sol).

---

## Security Contacts

- security@taiko.xyz
