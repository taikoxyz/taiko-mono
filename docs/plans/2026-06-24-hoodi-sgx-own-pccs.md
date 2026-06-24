# Hoodi SGX Own PCCS Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add scripts to deploy a Taiko-owned Automata DCAP/on-chain PCCS stack on Hoodi, load collateral for the local SGX quote, and verify/register the SGX instance through that owned stack.

**Architecture:** Reuse the DCAP/PCCS deployment scripts from PR 21724, but add an SGX-specific collateral setup script derived from the TDX extras script. The SGX script extracts FMSPC from an SGX v3 quote, fetches Intel SGX collateral, deploys/wires versioned PCCS DAOs, uploads signed JSON collateral, and leaves the resulting DCAP address usable by `SgxVerifier`.

**Tech Stack:** Bash, Python helper snippets, Foundry `forge`/`cast`, Intel PCS v4 APIs, Automata on-chain PCCS contracts.

---

### Task 1: Add a focused script test

**Files:**
- Create: `packages/protocol/script/layer1/verifiers/tests/test_setup_sgx_pccs_extras.py`

**Steps:**
1. Write a Python test that invokes `setup_sgx_pccs_extras.sh --extract-fmspc <bootstrap.json>` against `/tmp/provider-log-check-20260519/raiko2-sgx/config/bootstrap.json`.
2. Verify it fails before the script exists.
3. Expected final behavior: prints `00606a000000`.

### Task 2: Bring in DCAP/PCCS deployment script

**Files:**
- Create: `packages/protocol/script/layer1/verifiers/deploy_automata_dcap.sh`

**Steps:**
1. Restore the PR 21724 deploy script.
2. Keep it chain-generic and usable for SGX by allowing collateral setup to be handled by the separate SGX script.
3. Run `bash -n` on the script.

### Task 3: Add SGX PCCS extras script

**Files:**
- Create: `packages/protocol/script/layer1/verifiers/setup_sgx_pccs_extras.sh`

**Steps:**
1. Derive it from `setup_tdx_pccs_extras.sh`.
2. Use SGX PCS API endpoints.
3. Parse SGX v3 quote auth data using `48 + 384`.
4. Wire versioned DAOs for the selected SGX TCB evaluation number.
5. Upload SGX root/signing certs, root CRL, PCK Platform CA/CRL, TCB eval data, SGX TCB info, and QE identity.
6. Support `--extract-fmspc <bootstrap.json>` for a cheap parser test.

### Task 4: Verify locally

**Commands:**
- `python3 -m pytest packages/protocol/script/layer1/verifiers/tests/test_setup_sgx_pccs_extras.py`
- `bash -n packages/protocol/script/layer1/verifiers/deploy_automata_dcap.sh`
- `bash -n packages/protocol/script/layer1/verifiers/setup_sgx_pccs_extras.sh`

### Task 5: Run Hoodi deployment and registration smoke test

**Steps:**
1. Use `raiko2-k8s/hoodi.env` for RPC/key.
2. Deploy owned Automata DCAP/PCCS.
3. Run SGX extras for FMSPC `00606a000000`.
4. Deploy a fresh `InsecureSgxVerifier` pointing at owned DCAP.
5. Configure MRENCLAVE/MRSIGNER and call `registerInstance` using the local SGX quote.
6. Record addresses, tx hashes, and final verifier state.
