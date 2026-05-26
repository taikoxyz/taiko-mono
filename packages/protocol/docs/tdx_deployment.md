# TDX Prover Deployment

End-to-end guide for deploying a TDX prover for taiko-mono and registering it on-chain.

## Overview

The TDX prover runs a full Taiko stack (execution client + Raiko V2) inside a hardware-encrypted
Intel TDX confidential VM. Rather than the SGX preflight/proving split, the prover trusts
the local node's re-execution and produces an ECDSA signature over the proof's public input
hash. The on-chain `AzureTdxVerifier` admits keys after remote attestation (Azure vTPM + Intel TDX
DCAP) and then verifies proofs by checking that signature.

The wire format of a TDX proof matches `SgxVerifier`'s 89-byte layout
(`instance_id || address || signature`), so TDX can slot into any `ComposeVerifier`
configuration that accepts the SGX-style proof shape — it is exposed as
`ComposeVerifier.VerifierType.TDX_RETH`.

## Repository layout

| Repo                                                                | Role                                                                          |
| ------------------------------------------------------------------- | ----------------------------------------------------------------------------- |
| [`nethermind-tdx`](https://github.com/NethermindEth/nethermind-tdx) | Build the VM image (mkosi) + Azure deployment CLI                             |
| `taiko-mono` (`packages/protocol`)                                  | `AzureTdxVerifier.sol`, `ComposeVerifier` TDX wiring, deploy scripts          |
| [`raiko2`](https://github.com/taikoxyz/raiko2)                      | `TdxProver` (proof generation) + `xtask register-tdx` (on-chain registration) |

## Smart-contract dependency graph

```
AzureTdxVerifier
   ├── AutomataDcapAttestationFee  (DCAP entrypoint)
   │     └── PCCSRouter
   │           ├── AutomataPcsDao              (Intel PCS certs + CRLs)
   │           ├── AutomataPckDao              (PCK certs)
   │           ├── AutomataFmspcTcbDaoVersioned  (TCB info, keyed by tcbEvalNumber) ← V4 requires this
   │           ├── AutomataEnclaveIdentityDaoVersioned (QE identity, versioned)  ← V4 requires this
   │           └── AutomataTcbEvalDao          (TCB evaluation data numbers)
   └── AzureTDX library                 (vTPM RSA + PCR + nonce checks, inline)
```

`AzureTdxVerifier` is the only contract specific to Taiko. Everything below it is the Automata
on-chain PCCS + DCAP attestation stack, which is **chain-wide infrastructure**.

## When do I need to deploy Automata DCAP myself?

| Network                       | Automata DCAP `AutomataDcapAttestationFee` | Action                                             |
| ----------------------------- | ------------------------------------------ | -------------------------------------------------- |
| Mainnet / Hoodi / Known chain | Probably deployed                          | Use existing — only deploy `AzureTdxVerifier`      |
| Local Anvil / custom L1       | Nothing deployed                           | Deploy Automata + PCCS extras + `AzureTdxVerifier` |

The chain-wide infrastructure (DCAP + PCCS) only has to be deployed **once per L1**. Once
present, multiple Taiko / Surge instances on that L1 can each deploy their own `AzureTdxVerifier`
and reuse the shared DCAP + PCCS.

## Scripts

All scripts live in `packages/protocol/script/layer1/verifiers/`. They can be run independently
or chained together.

| Script                                                                                          | What it does                                                                                                                                                                                                                                                                         | When to use                                               |
| ----------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------------- |
| [`deploy_tdx_verifier.sh`](../script/layer1/verifiers/deploy_tdx_verifier.sh)                   | Deploys `AzureTdxVerifier` impl + ERC1967 proxy and transfers ownership. Optionally seeds trusted params + first instance                                                                                                                                                            | Mainnet, Hoodi, or any L1 where DCAP + PCCS already exist |
| [`deploy_automata_dcap.sh`](../script/layer1/verifiers/deploy_automata_dcap.sh)                 | Deploys the full Automata DCAP + PCCS stack (helpers, DAOs, PCCSRouter, V4QuoteVerifier, `AutomataDcapAttestationFee`). Loads Root CA + Signing certs. Auto-detects FMSPC from a running raiko2 if `RAIKO2_URL` is set                                                               | Custom L1 with no existing DCAP                           |
| [`setup_tdx_pccs_extras.sh`](../script/layer1/verifiers/setup_tdx_pccs_extras.sh)               | Deploys the **versioned** DAOs required by V4 TDX quotes (`AutomataFmspcTcbDaoVersioned`, `AutomataEnclaveIdentityDaoVersioned`), wires them into `PCCSRouter`, uploads PCK Platform CA + CRLs, and loads TCB info / QE identity / TCB eval data via the `LoadPccsData` forge script | Custom L1 — runs **after** `deploy_automata_dcap.sh`      |
| [`deploy_dcap_and_tdx_verifier.sh`](../script/layer1/verifiers/deploy_dcap_and_tdx_verifier.sh) | One-shot orchestrator: runs `deploy_automata_dcap.sh` → `setup_tdx_pccs_extras.sh` (if `RAIKO2_URL` is set) → `deploy_tdx_verifier.sh`, then writes a summary JSON with all addresses                                                                                                | Custom L1 bring-up from scratch                           |

## Prerequisites

| Tool                                      | Purpose                                                   |
| ----------------------------------------- | --------------------------------------------------------- |
| `mkosi`                                   | Build the VM disk image (in `nethermind-tdx`)             |
| `go`                                      | Run the Azure deploy CLI                                  |
| `azcopy`                                  | Upload the disk image to Azure (called by the deploy CLI) |
| `az` CLI                                  | Azure authentication (`az login` before deploying)        |
| `forge`, `cast`                           | Run the deploy scripts                                    |
| `cargo`                                   | Build and run `xtask register-tdx`                        |
| `jq`, `python3`, `curl`, `openssl`, `xxd` | Required by the bash scripts                              |

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

## Step 2 — Deploy the VM to Azure

**Repo:** `nethermind-tdx/tools/deploy-azure/main.go`

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

---

## Step 3 — Initialize the VM (first boot)

TDX-Init runs on first boot and opens an HTTP server on port 8080 waiting for an SSH public
key:

```bash
curl -X POST -d "$(cut -d' ' -f2 ~/.ssh/id_ed25519.pub)" http://<VM_IP>:8080
```

This triggers disk encryption, then systemd starts the execution client and raiko2. After
~1 minute raiko2's API is reachable:

```bash
curl http://<VM_IP>:8080/v3/proof/tdx/bootstrap | jq .
```

The response includes `quote`, `public_key`, `nonce`, and `metadata` (the Azure TDX
attestation document).

---

## Step 4 — Deploy the smart contracts

Two paths, depending on whether the L1 already has Automata DCAP deployed.

### Path A — L1 already has Automata DCAP (mainnet, Hoodi, surge devnet)

Only deploy `AzureTdxVerifier`:

```bash
cd packages/protocol

PRIVATE_KEY=0x...                       \
FORK_URL=https://<L1 RPC>               \
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
| `CONTRACT_OWNER`            | Final owner (Ownable2Step pendingOwner) — typically the timelock |
| `AUTOMATA_DCAP_ATTESTATION` | Existing chain-wide DCAP entrypoint (table above)                |
| `TAIKO_CHAIN_ID`            | L2 chain id; bound into proof signatures via `LibPublicInput`    |
| `BROADCAST`                 | `true` to actually send transactions                             |

### Path B — Custom L1 with no DCAP yet (local Anvil / custom devnet)

Use the one-shot orchestrator. It deploys DCAP, runs the PCCS extras (versioned DAOs + Intel
collateral upload), and deploys `AzureTdxVerifier` in sequence, then writes
`/tmp/deploy_summary_<chain_id>.json` with all relevant addresses.

```bash
cd packages/protocol

PRIVATE_KEY=0x...                              \
CONTRACT_OWNER=0x...                           \
TAIKO_CHAIN_ID=167001                          \
RPC_URL=http://localhost:8545                  \
RAIKO2_URL=http://<VM_IP>:8080                 \
./script/layer1/verifiers/deploy_dcap_and_tdx_verifier.sh
```

The script auto-detects the FMSPC from the raiko bootstrap and the current Intel TCB
evaluation data number. After it finishes:

```bash
$ cat /tmp/deploy_summary_3151908.json
{
  "chain_id": "3151908",
  "rpc_url": "http://localhost:8545",
  "AutomataDcapAttestationFee": "0xD4766820a09E8C4c6f4FE80a82DAC29972EFB681",
  "AzureTdxVerifier": "0x36C02dA8a0983159322a80FFE9F24b1acfF8B570",
  "pccs_json": "/tmp/pccs_3151908.json"
}
```

Use `AzureTdxVerifier` from this file in Step 5.

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
  --verifier $(jq -r .AzureTdxVerifier /tmp/deploy_summary_<chain_id>.json) \
  --rpc http://<L1 RPC>                                                \
  --private-key 0x<owner key>                                          \
  --raiko-url http://<VM_IP>:8080                                      \
  --trust --register
```

`--trust` calls `setTrustedParams` (owner-only — locks the running image's hardware
measurements). `--register` calls `registerInstance` (permissionless — runs the on-chain
attestation and admits the bootstrap key). For subsequent instances on the same image,
omit `--trust` and any funded key works.

---

## Wiring TDX into block-proof verification

The base `ComposeVerifier` and `getVerifierAddress` already route `TDX_RETH` through to a
`tdxRethVerifier` slot. To accept TDX proofs in production, add a concrete compose verifier
similar to `SgxAndZkVerifier` that wires `tdxRethVerifier` and accepts it in
`areVerifiersSufficient`. Then deploy that compose verifier with the `AzureTdxVerifier` proxy as
its TDX slot.

---

## Summary

| Step | Repo                         | Command                                                 |
| ---- | ---------------------------- | ------------------------------------------------------- |
| 1    | `nethermind-tdx`             | `make build IMAGE=taiko-tdx-prover`                     |
| 2    | `nethermind-tdx`             | `go run tools/deploy-azure/main.go deploy ...`          |
| 3    | VM                           | `curl -X POST -d "<ssh-pubkey>" http://<IP>:8080`       |
| 4a   | `taiko-mono` (mainnet/Hoodi) | `BROADCAST=true ./deploy_tdx_verifier.sh`               |
| 4b   | `taiko-mono` (custom L1)     | `./deploy_dcap_and_tdx_verifier.sh`                     |
| 5    | `raiko2`                     | `cargo run -p xtask -- register-tdx --trust --register` |
