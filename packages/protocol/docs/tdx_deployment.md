# TDX Prover Deployment

End-to-end guide for deploying a TDX prover for taiko-mono and registering it on-chain.

## Overview

The TDX prover runs a Nethermind execution client plus a minimal HTTP signing service
(`reth-tdx`) inside a hardware-encrypted Intel TDX confidential VM. raiko2 runs
**outside** the VM and forwards proof requests over HTTP — `reth-tdx` fetches the
corresponding L2 block from the co-resident Nethermind, signs the Shasta aggregation
hash with a TDX-bound bootstrap key, and returns the signed proof. An on-chain
TDX verifier admits keys after remote attestation and then verifies proofs by
checking that signature.

There are **two verifier variants**, selected by where/how the prover runs — every
deploy script below handles both via the `VERIFIER_KIND` env var (default `tdx`):

| `VERIFIER_KIND` | Contract           | Platform                             | Attestation                             | Boot measurements |
| --------------- | ------------------ | ------------------------------------ | --------------------------------------- | ----------------- |
| `azure`         | `AzureTdxVerifier` | Azure Confidential VMs               | Azure vTPM-bound TDX quote + Intel DCAP | vTPM **PCRs**     |
| `tdx` (default) | `GcpTdxVerifier`   | GCP Confidential VMs, bare-metal TDX | raw Intel TDX DCAP quote (configfs-tsm) | TDX **RTMR0..3**  |

Both verifiers use the **same** Automata DCAP stack (the quote format is identical),
so you deploy Automata once regardless of variant. The prover image's variant is
fixed at build time (`make build AZURE=true` → azure, `GCP=true` / bare-metal → tdx),
and `xtask register-tdx` auto-detects it from the bootstrap.

Moving the signing service into its own binary closes a trust gap in the previous
design: the attestation quote now binds the key to a TEE that sources L2 state from
a fixed, in-VM RPC, not from an arbitrary URL operators can point at.

The wire format of a TDX proof matches `SgxVerifier`'s 89-byte layout
(`instance_id || address || signature`), so TDX can slot into any `ComposeVerifier`
configuration that accepts the SGX-style proof shape — it is exposed as
`ComposeVerifier.VerifierType.TDX_RETH`.

## Repository layout

| Repo                                                                                            | Role                                                                                                 |
| ----------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| [`nethermind-tdx`](https://github.com/NethermindEth/nethermind-tdx)                             | Build the VM image (mkosi) + Azure / GCP deployment CLIs                                             |
| [`nethermind-tdx/reth-tdx`](https://github.com/NethermindEth/nethermind-tdx/tree/main/reth-tdx) | Remote TDX prover binary that ships inside the VM (HTTP server on :8080)                             |
| `taiko-mono` (`packages/protocol`)                                                              | `GcpTdxVerifier.sol` (native) + `AzureTdxVerifier.sol`, `ComposeVerifier` TDX wiring, deploy scripts |
| [`raiko2`](https://github.com/taikoxyz/raiko2)                                                  | `RethTdxProver` HTTP client (forwards proof requests to `reth-tdx`) + `xtask register-tdx`           |

## Smart-contract dependency graph

```
GcpTdxVerifier (native DCAP)   /   AzureTdxVerifier (Azure vTPM)
   ├── AutomataDcapAttestationFee  (DCAP entrypoint — SHARED by both)
   │     └── PCCSRouter
   │           ├── AutomataPcsDao              (Intel PCS certs + CRLs)
   │           ├── AutomataPckDao              (PCK certs)
   │           ├── AutomataFmspcTcbDaoVersioned  (TCB info, keyed by tcbEvalNumber) ← V4 requires this
   │           ├── AutomataEnclaveIdentityDaoVersioned (QE identity, versioned)  ← V4 requires this
   │           └── AutomataTcbEvalDao          (TCB evaluation data numbers)
   └── (azure only) AzureTDX library    (vTPM RSA + PCR + nonce checks, inline)
```

The TDX verifier (`GcpTdxVerifier` for native DCAP, `AzureTdxVerifier` for the Azure
vTPM flow) is the only contract specific to Taiko. Both consume the **same** Automata
DCAP entrypoint below them — that is **chain-wide infrastructure**. `GcpTdxVerifier`
checks the quote's RTMRs directly; `AzureTdxVerifier` adds the inline `AzureTDX` vTPM
layer and checks PCRs.

## When do I need to deploy Automata DCAP myself?

| Network                       | Automata DCAP `AutomataDcapAttestationFee` | Action                                           |
| ----------------------------- | ------------------------------------------ | ------------------------------------------------ |
| Mainnet / Hoodi / Known chain | Probably deployed                          | Use existing — only deploy the TDX verifier      |
| Local Anvil / custom L1       | Nothing deployed                           | Deploy Automata + PCCS extras + the TDX verifier |

The chain-wide infrastructure (DCAP + PCCS) only has to be deployed **once per L1**, and is
shared across both verifier variants. Once present, multiple Taiko / Surge instances on that
L1 can each deploy their own `GcpTdxVerifier` / `AzureTdxVerifier` and reuse the shared DCAP +
PCCS.

## Scripts

All scripts live in `packages/protocol/script/layer1/verifiers/`. They can be run independently
or chained together. **Every script supports both verifier variants** — `deploy_tdx_verifier.sh`
and the orchestrator pick the contract from `VERIFIER_KIND` (`tdx` default / `azure`), while
`deploy_automata_dcap.sh` and `setup_tdx_pccs_extras.sh` auto-detect the FMSPC from either an
Azure or a native bootstrap quote, so the Automata/PCCS stack is variant-agnostic.

| Script                                                                                          | What it does                                                                                                                                                                                                                                                                         | When to use                                               |
| ----------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------------- |
| [`deploy_tdx_verifier.sh`](../script/layer1/verifiers/deploy_tdx_verifier.sh)                   | Deploys the TDX verifier impl + ERC1967 proxy and transfers ownership (`GcpTdxVerifier` for `VERIFIER_KIND=tdx`, `AzureTdxVerifier` for `azure`). Optionally seeds trusted params                                                                                                    | Mainnet, Hoodi, or any L1 where DCAP + PCCS already exist |
| [`deploy_automata_dcap.sh`](../script/layer1/verifiers/deploy_automata_dcap.sh)                 | Deploys the full Automata DCAP + PCCS stack (helpers, DAOs, PCCSRouter, V4QuoteVerifier, `AutomataDcapAttestationFee`). Loads Root CA + Signing certs. Auto-detects FMSPC from a running reth-tdx (azure or native quote) if `RETH_TDX_URL` is set                                   | Custom L1 with no existing DCAP                           |
| [`setup_tdx_pccs_extras.sh`](../script/layer1/verifiers/setup_tdx_pccs_extras.sh)               | Deploys the **versioned** DAOs required by V4 TDX quotes (`AutomataFmspcTcbDaoVersioned`, `AutomataEnclaveIdentityDaoVersioned`), wires them into `PCCSRouter`, uploads PCK Platform CA + CRLs, and loads TCB info / QE identity / TCB eval data via the `LoadPccsData` forge script | Custom L1 — runs **after** `deploy_automata_dcap.sh`      |
| [`deploy_dcap_and_tdx_verifier.sh`](../script/layer1/verifiers/deploy_dcap_and_tdx_verifier.sh) | One-shot orchestrator: runs `deploy_automata_dcap.sh` → `setup_tdx_pccs_extras.sh` (if `RETH_TDX_URL` is set) → `deploy_tdx_verifier.sh` (honoring `VERIFIER_KIND`), then writes a summary JSON with all addresses                                                                   | Custom L1 bring-up from scratch                           |

## Prerequisites

| Tool                                      | Purpose                                                                                 |
| ----------------------------------------- | --------------------------------------------------------------------------------------- |
| `mkosi`                                   | Build the VM disk image (in `nethermind-tdx`)                                           |
| `go`                                      | Run the Azure/GCP deploy CLIs                                                           |
| `azcopy`, `az` CLI                        | **Azure only:** image upload + auth (`az login`)                                        |
| `gcloud` CLI                              | **GCP only:** Application Default Credentials (`gcloud auth application-default login`) |
| `forge`, `cast`                           | Run the deploy scripts                                                                  |
| `cargo`                                   | Build and run `xtask register-tdx`                                                      |
| `jq`, `python3`, `curl`, `openssl`, `xxd` | Required by the bash scripts                                                            |

---

## Step 1 — Build the VM image

**Repo:** [nethermind-tdx](https://github.com/NethermindEth/nethermind-tdx)

Configure `env.json` (see `env.json.example`) with chain RPC endpoints, Raiko V2 config, etc.,
then build:

```bash
make build IMAGE=taiko-tdx-prover
# outputs: build/taiko-tdx-prover_<version>.vhd
```

The image contains the L1/L2 execution client, raiko2 (with the `tdx` feature), the `tdxs`
daemon (TDX quote abstraction layer), and `TDX-Init` (first-boot disk encryption + SSH
provisioning).

---

## Step 2 — Deploy the VM (Azure or GCP)

Use the deploy CLI matching your prover platform. **Azure** (`tools/deploy-azure`)
gives an `azure`-issuer prover; **GCP** (`tools/deploy-gcp`) gives a native `tdx`-issuer
prover. Full per-platform instructions live in the
[nethermind-tdx README](https://github.com/NethermindEth/nethermind-tdx/blob/main/README.md).

**Azure** — `nethermind-tdx/tools/deploy-azure/main.go`:

```bash
cd nethermind-tdx

go run tools/deploy-azure/main.go deploy \
    --id <deployment-id>            \
    --region eastus                 \
    --resource-group <rg-name>      \
    --vm-size Standard_EC4es_v6     \
    --storage-gb 100                \
    --disk-path build/taiko-tdx-prover_<version>.vhd \
    --allowed-ip <your-ip>          \
    --subscription-id <sub-id>      \
    --tenant-id <tenant-id>
```

Creates a Confidential VM (`SecurityType=ConfidentialVM`, `VTpmEnabled=true`), uploads the
`.vhd` via `azcopy`, sets up the NSG, returns the public IP.

**GCP** — `nethermind-tdx/tools/deploy-gcp` (Intel TDX on the C3 family; `.tar.gz` image
from `make build … GCP=true`):

```bash
cd nethermind-tdx

go run ./tools/deploy-gcp deploy \
    --id <deployment-id>            \
    --project <gcp-project>         \
    --bucket <gcs-bucket>           \
    --disk-path build/taiko-tdx-prover-gcp-dev_<version>.tar.gz \
    --zone us-central1-a            \
    --machine-type c3-standard-4    \
    --network <vpc>                 \
    --allowed-ip <your-ip>/32
```

Whichever platform you pick, the rest of this guide is the same — just set
`VERIFIER_KIND` accordingly in Step 4 (`azure` for the Azure VM, `tdx` for the GCP VM).

---

## Step 3 — Initialize the VM (first boot)

TDX-Init runs on first boot and opens an HTTP server on port 8080 waiting for an SSH public
key:

```bash
curl -X POST -d "$(cut -d' ' -f2 ~/.ssh/id_ed25519.pub)" http://<VM_IP>:8080
```

This triggers disk encryption, then systemd starts the execution client and `reth-tdx`.
After ~1 minute `reth-tdx`'s API is reachable:

```bash
curl http://<VM_IP>:8080/bootstrap | jq .
```

The response is a flat JSON object with `quote`, `public_key`, `nonce`, `issuer_type`,
and `metadata` (the Azure TDX attestation document).

---

## Step 4 — Deploy the smart contracts

Two paths, depending on whether the L1 already has Automata DCAP deployed.

### Path A — L1 already has Automata DCAP (mainnet, Hoodi, surge devnet)

Only deploy the TDX verifier. Set `VERIFIER_KIND` for your prover platform
(`tdx` for GCP/bare-metal — the default — or `azure`):

```bash
cd packages/protocol

PRIVATE_KEY=0x...                       \
FORK_URL=https://<L1 RPC>               \
VERIFIER_KIND=tdx                       \
CONTRACT_OWNER=0x...                    \
AUTOMATA_DCAP_ATTESTATION=0x8d7C95...   \
TAIKO_CHAIN_ID=167000                   \
BROADCAST=true                          \
./script/layer1/verifiers/deploy_tdx_verifier.sh
```

| Variable                    | Description                                                      |
| --------------------------- | ---------------------------------------------------------------- |
| `PRIVATE_KEY`               | Deployer key                                                     |
| `FORK_URL`                  | L1 RPC URL                                                       |
| `VERIFIER_KIND`             | `tdx` (GcpTdxVerifier, default) or `azure` (AzureTdxVerifier)    |
| `CONTRACT_OWNER`            | Final owner (Ownable2Step pendingOwner) — typically the timelock |
| `AUTOMATA_DCAP_ATTESTATION` | Existing chain-wide DCAP entrypoint (table above)                |
| `TAIKO_CHAIN_ID`            | L2 chain id; bound into proof signatures via `LibPublicInput`    |
| `BROADCAST`                 | `true` to actually send transactions                             |

### Path B — Custom L1 with no DCAP yet (local Anvil / custom devnet)

Use the one-shot orchestrator. It deploys DCAP, runs the PCCS extras (versioned DAOs + Intel
collateral upload), and deploys the TDX verifier (selected by `VERIFIER_KIND`, default `tdx`)
in sequence, then writes `/tmp/deploy_summary_<chain_id>.json` with all relevant addresses.

```bash
cd packages/protocol

PRIVATE_KEY=0x...                              \
CONTRACT_OWNER=0x...                           \
TAIKO_CHAIN_ID=167001                          \
RPC_URL=http://localhost:8545                  \
RETH_TDX_URL=http://<VM_IP>:8080               \
VERIFIER_KIND=tdx                              \
./script/layer1/verifiers/deploy_dcap_and_tdx_verifier.sh
```

`VERIFIER_KIND=tdx` (default) deploys `GcpTdxVerifier` for a GCP / bare-metal prover;
`VERIFIER_KIND=azure` deploys `AzureTdxVerifier` for an Azure prover. Either way the script
auto-detects the FMSPC from the reth-tdx bootstrap (both quote formats are supported) and the
current Intel TCB evaluation data number. After it finishes:

```bash
$ cat /tmp/deploy_summary_3151908.json
{
  "chain_id": "3151908",
  "rpc_url": "http://localhost:8545",
  "AutomataDcapAttestationFee": "0xD4766820a09E8C4c6f4FE80a82DAC29972EFB681",
  "verifier_kind": "tdx",
  "tdx_verifier": "0x36C02dA8a0983159322a80FFE9F24b1acfF8B570",
  "pccs_json": "/tmp/pccs_3151908.json"
}
```

Use `tdx_verifier` from this file in Step 5.

#### Why the orchestrator does three things, not one

`deploy_automata_dcap.sh` deploys the legacy (non-versioned) DAOs that are sufficient for V3
SGX quotes. V4 TDX quotes additionally require versioned DAOs keyed by Intel's
`tcbEvaluationDataNumber` — those are deployed by `setup_tdx_pccs_extras.sh`. Skipping the
extras step on a custom devnet causes `registerInstance` to revert with
`TcbEvalExpiredOrNotFound(TcbId=1)` (selector `0xa78bf21a`).

#### Skipping individual steps

The orchestrator is a thin wrapper; you can call any of the three scripts on its own. The
companion script will skip already-completed work (idempotent on the same chain).

---

## Step 5 — Register the TDX instance

Registration runs the on-chain attestation that admits the bootstrap public key to the
verifier's instance registry. See the dedicated guide in raiko2:

[**raiko2 — Registering a TDX prover on-chain**](https://github.com/taikoxyz/raiko2/blob/main/docs/tdx_register.md)

Short version (first-time, owner key required):

```bash
cd raiko2

cargo run -p xtask -- register-tdx \
  --verifier $(jq -r .tdx_verifier /tmp/deploy_summary_<chain_id>.json) \
  --rpc http://<L1 RPC>                                                \
  --private-key 0x<owner key>                                          \
  --reth-tdx-url http://<VM_IP>:8080                                   \
  --trust --register
```

`--trust` calls `setTrustedParams` (owner-only — locks the running image's hardware
measurements). `--register` calls `registerInstance` (permissionless — runs the on-chain
attestation and admits the bootstrap key). For subsequent instances on the same image,
omit `--trust` and any funded key works.

---

## Step 6 — Verify a proof (optional smoke test)

To confirm the deployment end-to-end, fetch a real proof from raiko2 and call the verifier's
`verifyProof(uint256,bytes32,bytes)` (a `view` that reverts on an invalid proof). The only
non-trivial part is computing `_commitmentHash` = `hash_commitment(Commitment)` built from the
proof's `proof_carry_data` — **not** the proof's `input` field, and **not**
`hash_shasta_subproof_input`. The full recipe (identical for Azure and GCP) and a ready-made
helper are in
[raiko2 — Registering a TDX prover § Verifying a proof on-chain](https://github.com/taikoxyz/raiko2/blob/main/docs/tdx_register.md#verifying-a-proof-on-chain).

---

## Wiring TDX into block-proof verification

The base `ComposeVerifier` and `getVerifierAddress` already route `TDX_RETH` through to a
`tdxRethVerifier` slot. To accept TDX proofs in production, add a concrete compose verifier
similar to `SgxAndZkVerifier` that wires `tdxRethVerifier` and accepts it in
`areVerifiersSufficient`. Then deploy that compose verifier with the TDX verifier proxy
(`GcpTdxVerifier` or `AzureTdxVerifier`) as its TDX slot.

---

## Summary

| Step | Repo                         | Command                                                                                                                                                                 |
| ---- | ---------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1    | `nethermind-tdx`             | `make build IMAGE=taiko-tdx-prover` (`AZURE=true` / `GCP=true`)                                                                                                         |
| 2    | `nethermind-tdx`             | `go run tools/deploy-azure ...` or `go run ./tools/deploy-gcp ...`                                                                                                      |
| 3    | VM                           | `curl -X POST -d "<ssh-pubkey>" http://<IP>:8080`                                                                                                                       |
| 4a   | `taiko-mono` (mainnet/Hoodi) | `VERIFIER_KIND=tdx BROADCAST=true ./deploy_tdx_verifier.sh`                                                                                                             |
| 4b   | `taiko-mono` (custom L1)     | `VERIFIER_KIND=tdx ./deploy_dcap_and_tdx_verifier.sh`                                                                                                                   |
| 5    | `raiko2`                     | `cargo run -p xtask -- register-tdx --trust --register` (auto-detects kind)                                                                                             |
| 6    | (optional)                   | verify a proof on-chain — see [register doc § Verifying a proof on-chain](https://github.com/taikoxyz/raiko2/blob/main/docs/tdx_register.md#verifying-a-proof-on-chain) |
